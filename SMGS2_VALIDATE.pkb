/* Formatted on 19/12/2022 17:28:59 (QP5 v5.381) */
CREATE OR REPLACE PACKAGE BODY spv.smgs2_validate
AS
    /******************************************************************************
       NAME:       smgs_validate
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        27.11.2013                    Created this package.
       1.1        18.01.2021  M.Tars            Added stamp (tempel) functionality:
                                                - validate_tempels, currently no checks, see validate_document.
       1.2        23.04.2021  I.Daniilov        Added leads ("plommid") validation functionality:
                                                - validate_leads, currently no checks, see validate_document.
       1.3        17.08.2021  M.Tars            Logging changeover and increment to logger_service.logger;
                                                deleted FUNCTION var_to_xml (was already moved into sk.pack_and_send).
       1.4        11.10.2021  I.Jentson         Fixed smgs.border uninitialisation error (in xml_to_var).
       1.4.1      02.12.2021  M.Tars            Fixes in combine_collections:
                                                    initialize p_smgs.border and p_smgs.goods (goods.c001).description_text;
                                                    in "FOR goods IN" added "ORDER BY tonumber (c001)";
                                                    in "BULK COLLECT INTO p_smgs.goods (goods.c001).package", "...label" and "...dangerous_goods_stamps" statements.
       1.4.2      07.12.2021  M.Tars            Fixes in combine_collections for documents - added doc_name, rw_admin, doc_count and changed created_at format;
                                                fixes in save_document for documents - change docnumber value calculations.
       1.4.3      13.12.2021  H.Haljand         Changes in xml_to_var for p_smgs.goods.description_text and p_smgs.goods.name_comment to handle FTX+AAA and FTX+PRD segments.
       1.5        11.10.2021  H.Haljand         Packages spv.smgs2_interface ja spv.smgs2_validate now have additional goods descriptions.
       1.5.1      15.10.2021  M.Tars            Changed xml_to_var texts part to handle long texts for FTX+DCL segments.
       1.6        18.10.2021  H.Haljand         OKPO code validation according to parameters set in the edifact.sonumivahetuse_parameetrid table.
       1.6.1      16.12.2021  M.Tars            Changes in xml_to_var - containerType and equipmentType separated into wagon.container and wagon.equipment accordingly;
                                                changes in save_document - introduced saving of wagon.equipment.
       1.6.2      03.01.2022  M.Tars            Change in combine_collections - initialize wagon.equipment (equipments as non-containers) needed in save_document.
       1.7        20.10.2021  H.Haljand         Validate XML message danger goods sign format.
       1.7.1      24.01.2022  H.Haljand         Changes in validate_goods - clean up danger goods sign before validation.
       1.8        26.10.2021  M.Tars            Changes in combine_collections for consolidated packages of goods, fixes for goods and documents.
       1.9        02.11.2021  M.Tars            Changes in combine_collections and save_document for texts with smgs_role BLR or AEA.
       1.9.1      31.01.2022  M.Tars            Changes in xml_to_var - for texts with smgs_role BLR or AEA in case text length > 350.
       1.10       24.11.2021  M.Tars            Changes in combine_collections and save_document for texts with smgs_role TRA.
       1.10.1     01.02.2022  M.Tars            Changes in validate_texts - for texts with smgs_role BLR or AEA or TRA or DCL in case text length > 350.
       1.10.2     02.02.2022  M.Tars            Changes in xml_to_var - for texts with smgs_role TRA - CLOB-based handling introduced;
                                                changes in combine_collections - defragmentation for texts with smgs_role TRA.
       1.11       02.02.2022  H.Haljand         Uninitialised smgs.tempel fix
       1.12       14.02.2022  M.Tars            Changes in combine_collections and save_document for wagon leads and container leads.
       1.13       28.02.2022  M.Tars            Changes in combine_collections and xml_to_var for texts with smgs_role DCL.
       1.14       28.03.2022  H.Haljand         Size code and type code are concatenated for edifact.seadmed.seadme_tyyp
       2.1        07.04.2022  M.Tars            Added split_text_into_smgs and split_text_into_db, changes in save_document and xml_to_var - p_document.goods.name_comment type change and goods description changes.
       2.2        14.04.2022  H.Haljand         XML diff fixes - paperfree, weightdetermined, previousGoods
       2.3        04.08.2022  A.Org             changes in validate_document, validate_undertakers_data, validate_payers_data, validate_stations, save_document - added smgs.dokum_kood check ,
                                                changes in xml_to_var - added messageType, p_smgs.dokum_kood (VJS-711)
       2.4        12.08.2022  A.Org             changes in validate_wagons - added smgs.dokum_kood checks (VJS-711)
       2.5        16.08.2022  A.Org             changes in NVL(smgs.dokum_kood, ...) (VJS-711)
       2.6        06.09.2022  A.Org             changes in xml_to_var - added jobtitle (VJS-711)
       2.7        12.09.2022  A.Org             changes in xml_to_var - added wagon/previousGoods/dangerGoods/@description, wagon/@notes (VJS-711)
       2.8        14.09.2022  A.Org             changes in xml_to_var - changed wagon/previousGoods handling in sql xml (VJS-711)
       2.9        22.09.2022  M.Tars            changes in combine_collections - for wagon previous goods.
       2.10       25.11.2022  A.Org             changes in xml_to_var - added stationTransitBorderIn (VJS-711, VJS-715)
       2.11       01.12.2022  M.Tars            Changes in combine_collections - added element_index and positsioon when handling collections with name of packages_coll_name.
       2.12       14.12.2022  H.Haljand         Added "edilevel" and "position" to packages
       2.13       19.12.2022  M.Tars            Changes in xml_to_var - CURRENT_IFTMIN_XSD_VERSION usage and "position" to "positsioon" (only in XML will be "position"),
                                                changes in save_document - package attributes element_index and positsioon added.
       2.14       16.02.2023  H.Haljand         Package amounts are validated against configuration by package type code
    ******************************************************************************/
    PROCEDURE insert_attribute (p_xml       IN OUT XMLTYPE
                               ,p_path      IN     VARCHAR2
                               ,p_attr_name IN     VARCHAR
                               ,p_attr_val  IN     VARCHAR2
                               ,p_mandatory IN     BOOLEAN DEFAULT FALSE)
    IS
        l_params logger_service.logger.tab_param;
    BEGIN
        IF    p_attr_val IS NOT NULL
           OR p_mandatory
        THEN
            SELECT insertchildxml ((p_xml)
                                  ,p_path
                                  ,'@'
                                   || p_attr_name
                                  ,dbms_xmlgen.convert (p_attr_val))
              INTO p_xml
              FROM dual;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_attr_name IN'
                                               ,p_attr_name);
            logger_service.logger.append_param (l_params
                                               ,'p_path      IN'
                                               ,p_path);
            logger_service.logger.append_param (l_params
                                               ,'p_attr_val  IN'
                                               ,p_attr_val);
            logger_service.logger.log_error (p_text   => 'Inserting attribute"'
                                                        || p_attr_name
                                                        || '" into "'
                                                        || p_path
                                                        || '" failed: '
                                                        || sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.insert_attribute'
                                            ,p_params => l_params);
    END insert_attribute;

    PROCEDURE insert_element (p_xml          IN OUT XMLTYPE
                             ,p_path         IN     VARCHAR2
                             ,p_element_name IN     VARCHAR
                             ,p_element_xml  IN     XMLTYPE)
    IS
        l_params logger_service.logger.tab_param;
    BEGIN
        SELECT insertchildxml ((p_xml)
                              ,p_path
                              ,p_element_name
                              ,p_element_xml)
          INTO p_xml
          FROM dual;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_path         IN'
                                               ,p_path);
            logger_service.logger.append_param (l_params
                                               ,'p_element_name IN'
                                               ,p_element_name);
            logger_service.logger.log_error (p_text   => 'Inserting element"'
                                                        || p_element_name
                                                        || '" into "'
                                                        || p_path
                                                        || '" failed: '
                                                        || sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.insert_element'
                                            ,p_params => l_params);
    END insert_element;

    FUNCTION remove_line_break (p_text IN VARCHAR2)
        RETURN VARCHAR2
    IS
        z_text   VARCHAR2 (32767) := p_text;
        l_params logger_service.logger.tab_param;
    BEGIN
        z_text :=
            replace (z_text
                    ,chr (10)
                    ,NULL);
        z_text :=
            replace (z_text
                    ,chr (13)
                    ,NULL);
        z_text :=
            replace (z_text
                    ,chr (9)
                    ,NULL);
        RETURN z_text;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_text IN'
                                               ,p_text);
            logger_service.logger.append_param (l_params
                                               ,'RETURN z_text'
                                               ,z_text);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.remove_line_break'
                                            ,p_params => l_params);
            RETURN p_text;
    END remove_line_break;

    PROCEDURE debug_message (p_message IN VARCHAR2
                            ,p_realm   IN VARCHAR DEFAULT 'info')
    IS
        l_params logger_service.logger.tab_param;
    BEGIN
        IF user = 'SASS'
        THEN
            BEGIN
                dbms_output.put_line ($$plsql_unit
                                      || '. '
                                      || p_message
                                      || '. p_realm='
                                      || quote (p_realm));
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        ELSE
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_message IN'
                                               ,p_message);
            logger_service.logger.append_param (l_params
                                               ,'p_realm   IN'
                                               ,p_realm);

            CASE lower (p_realm)
                WHEN 'error'
                THEN
                    logger_service.logger.log_warn (p_text   => 'debug_message with level ERROR'
                                                   ,p_scope  => 'spv.'
                                                               || $$plsql_unit
                                                               || '.debug_message'
                                                   ,p_params => l_params);
                WHEN 'warning'
                THEN
                    logger_service.logger.log_warn (p_text   => 'debug_message with level '
                                                               || upper (p_realm)
                                                   ,p_scope  => 'spv.'
                                                               || $$plsql_unit
                                                               || '.debug_message'
                                                   ,p_params => l_params);
                ELSE
                    logger_service.logger.log_info (p_text   => 'debug_message with level '
                                                               || upper (p_realm)
                                                   ,p_scope  => 'spv.'
                                                               || $$plsql_unit
                                                               || '.debug_message'
                                                   ,p_params => l_params);
            END CASE;
        END IF;
    END debug_message;

    PROCEDURE add_message (p_message        IN VARCHAR2
                          ,p_realm          IN VARCHAR DEFAULT 'info'
                          ,p_code           IN VARCHAR2 DEFAULT NULL
                          ,p_replacement1   IN VARCHAR2 DEFAULT NULL
                          ,p_replacement2   IN VARCHAR2 DEFAULT NULL
                          ,p_replacement3   IN VARCHAR2 DEFAULT NULL
                          ,p_replacement4   IN VARCHAR2 DEFAULT NULL
                          ,p_replacement5   IN VARCHAR2 DEFAULT NULL
                          ,p_www_tekstid_id IN NUMBER DEFAULT NULL)
    IS
        z_index   PLS_INTEGER;
        z_message VARCHAR2 (512);
        z_realm   VARCHAR2 (16);
        l_params  logger_service.logger.tab_param;
    BEGIN
        CASE lower (p_realm)
            WHEN 'error'
            THEN
                z_realm := 'error';
            WHEN 'warning'
            THEN
                z_realm := 'warning';
            ELSE
                z_realm := 'info';
        END CASE;

        BEGIN
            message.extend;
        EXCEPTION
            WHEN OTHERS
            THEN
                -- init
                message := tb_validation_message ();
                message.delete;
                message.extend;
        END;

        BEGIN
            IF p_www_tekstid_id IS NOT NULL
            THEN
                z_message :=
                    substr (sass.get_tekst_in_lang (p_www_tekstid_id
                                                   ,NULL
                                                   ,v ('APP_USER'))
                           ,1
                           ,511);
            ELSE
                z_message :=
                    substr (p_message
                           ,1
                           ,511);
            END IF;

            IF     instr (z_message
                         ,'%1') > 0
               AND p_replacement1 IS NOT NULL
            THEN
                z_message :=
                    replace (z_message
                            ,'%1'
                            ,p_replacement1);
            END IF;

            IF     instr (z_message
                         ,'%2') > 0
               AND p_replacement2 IS NOT NULL
            THEN
                z_message :=
                    replace (z_message
                            ,'%2'
                            ,p_replacement2);
            END IF;

            IF     instr (z_message
                         ,'%3') > 0
               AND p_replacement3 IS NOT NULL
            THEN
                z_message :=
                    replace (z_message
                            ,'%3'
                            ,p_replacement3);
            END IF;

            IF     instr (z_message
                         ,'%4') > 0
               AND p_replacement4 IS NOT NULL
            THEN
                z_message :=
                    replace (z_message
                            ,'%4'
                            ,p_replacement4);
            END IF;

            IF     instr (z_message
                         ,'%5') > 0
               AND p_replacement5 IS NOT NULL
            THEN
                z_message :=
                    replace (z_message
                            ,'%5'
                            ,p_replacement5);
            END IF;
        --         debug_message(z_message, z_realm);
        EXCEPTION
            WHEN OTHERS
            THEN
                z_message :=
                    substr (p_message
                           ,1
                           ,511);
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'p_message IN'
                                                   ,p_message);
                logger_service.logger.append_param (l_params
                                                   ,'p_realm   IN'
                                                   ,p_realm);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.add_message - replacement'
                                                ,p_params => l_params);
        END;

        z_index                          := message.count;
        message (z_index).message        := nvl (z_message, p_message);
        message (z_index).realm          := z_realm;
        message (z_index).code           := p_code;
        message (z_index).www_tekstid_id := p_www_tekstid_id;
        message (z_index).replacement1   :=
            substr (p_replacement1
                   ,1
                   ,128);
        message (z_index).replacement2   :=
            substr (p_replacement2
                   ,1
                   ,128);
        message (z_index).replacement3   :=
            substr (p_replacement3
                   ,1
                   ,128);
        message (z_index).replacement4   :=
            substr (p_replacement4
                   ,1
                   ,128);
        message (z_index).replacement5   :=
            substr (p_replacement5
                   ,1
                   ,128);
        debug_message ('SMGS2_VALIDATE.add_message: p_message='
                       || quote (z_message)
                      ,p_realm);
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_message IN'
                                               ,p_message);
            logger_service.logger.append_param (l_params
                                               ,'p_realm   IN'
                                               ,p_realm);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.add_message'
                                            ,p_params => l_params);
    END add_message;

    FUNCTION get_number (p_str_number VARCHAR2)
        RETURN NUMBER
    IS
        z_out    NUMBER := NULL;
        l_params logger_service.logger.tab_param;
    BEGIN
        BEGIN
            z_out := tonumber (p_str_number);

            RETURN z_out;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'p_str_number'
                                                   ,p_str_number);
                logger_service.logger.append_param (l_params
                                                   ,'z_out'
                                                   ,z_out);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.get_number - TO_NUMBER (p_str_number)'
                                                ,p_params => l_params);
        END;

        BEGIN
            z_out :=
                to_number (replace (p_str_number
                                   ,','
                                   ,'.'));
            RETURN z_out;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'p_str_number'
                                                   ,p_str_number);
                logger_service.logger.append_param (l_params
                                                   ,'z_out'
                                                   ,z_out);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.get_number - TO_NUMBER (REPLACE (p_str_number,",","."))'
                                                ,p_params => l_params);
        END;

        BEGIN
            z_out :=
                to_number (replace (p_str_number
                                   ,'.'
                                   ,','));
            RETURN z_out;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'p_str_number'
                                                   ,p_str_number);
                logger_service.logger.append_param (l_params
                                                   ,'z_out'
                                                   ,z_out);
                logger_service.logger.log_error (p_text   => 'String number="'
                                                            || p_str_number
                                                            || '" and no solution.. returned null: '
                                                            || sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.get_number - TO_NUMBER (REPLACE (p_str_number,".",","))'
                                                ,p_params => l_params);
                RETURN NULL;
        END;
    END get_number;

    FUNCTION get_undertaker_state (p_undertaker_rics_code IN vedajad_rics.kood%TYPE)
        RETURN riigid.lyhend%TYPE
    IS
        result   riigid.lyhend%TYPE;
        l_params logger_service.logger.tab_param;
    BEGIN
        SELECT (SELECT lyhend
                  FROM riigid
                 WHERE kood3 = riik_kood3)    AS riigi_lyhend
          INTO result
          FROM vedajad_rics
         WHERE kood = p_undertaker_rics_code;

        RETURN result;
    EXCEPTION
        WHEN no_data_found
        THEN
            RETURN NULL;
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_undertaker_rics_code IN'
                                               ,p_undertaker_rics_code);
            logger_service.logger.append_param (l_params
                                               ,'RETURN result'
                                               ,result);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.get_undertaker_state'
                                            ,p_params => l_params);
    END get_undertaker_state;

    PROCEDURE correct_wagon_data (p_wagon       IN OUT spv.smgs2_interface.t_edi_wagon
                                 ,p_smgs_number IN     VARCHAR2)
    IS
        l_params logger_service.logger.tab_param;
    BEGIN
        SELECT rw_admin, capacity, axis, net_weight, kalibr_code, provider
          INTO p_wagon.rw_admin, p_wagon.capacity, p_wagon.axis, p_wagon.net_weight, p_wagon.kalibr_code, p_wagon.provider
          FROM (SELECT nvl (p_wagon.rw_admin, l.sob)                          rw_admin
                      ,nvl (p_wagon.capacity, (l.gruzp / 10))                 capacity
                      ,nvl (p_wagon.axis, vt.telgede_arv)                     axis
                      ,nvl (p_wagon.net_weight, l.tara / 10)                  net_weight
                      ,nvl (p_wagon.kalibr_code, nvl (m.kalibrovka, '0'))     kalibr_code
                      ,nvl (p_wagon.provider, 1)                              provider
                  FROM ibmu.lmvb_vagon    l
                      ,ibmu.vagunityybid  vt
                      ,ibmu.model         m
                 WHERE     l.nvag = p_wagon.wagon_nr
                       AND vt.kood = l.tip
                       AND l.model_kod = m.model(+)
                       AND m.cor_tip(+) NOT IN ('D')
                UNION
                SELECT nvl (p_wagon.rw_admin, l.sob)
                      ,nvl (p_wagon.capacity, (nvl (l.gruzp / 10, 1)))     kandevqime
                      ,nvl (p_wagon.axis, l.kol_os)
                      ,nvl (p_wagon.net_weight, l.tara / 10)               taara_kaal
                      ,nvl (p_wagon.kalibr_code, '0')
                      ,nvl (p_wagon.provider, 1)
                  FROM ibmu.lmvb_vagon_ee l
                 WHERE    l.nvag = p_wagon.wagon_nr
                       OR l.nvag_s = p_wagon.wagon_nr);

        IF p_wagon.goods_weight IS NULL
        THEN
            p_wagon.goods_weight := 0;
        END IF;
    EXCEPTION
        WHEN no_data_found
        THEN
            log_debug ($$plsql_unit
                       || '.validate_wagons'
                      ,'Saadetise nr:'
                       || p_smgs_number
                       || ' Tuundmatu vaguninumber "'
                       || p_wagon.wagon_nr
                       || '"');
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_smgs_number IN'
                                               ,p_smgs_number);
            logger_service.logger.append_param (l_params
                                               ,'p_wagon.wagon_nr'
                                               ,p_wagon.wagon_nr);
            logger_service.logger.append_param (l_params
                                               ,'p_wagon.rw_admin'
                                               ,p_wagon.rw_admin);
            logger_service.logger.append_param (l_params
                                               ,'p_wagon.capacity'
                                               ,p_wagon.capacity);
            logger_service.logger.append_param (l_params
                                               ,'p_wagon.axis'
                                               ,p_wagon.axis);
            logger_service.logger.append_param (l_params
                                               ,'p_wagon.net_weight'
                                               ,p_wagon.net_weight);
            logger_service.logger.append_param (l_params
                                               ,'p_wagon.kalibr_code'
                                               ,p_wagon.kalibr_code);
            logger_service.logger.append_param (l_params
                                               ,'p_wagon.provider'
                                               ,p_wagon.provider);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.correct_wagon_data'
                                            ,p_params => l_params);
            RETURN;
    END correct_wagon_data;

    ------------------------------
    -- Function return comma-separated countries list of all participants
    -- Purpose:
    -- to check if all border stations exists.
    ------------------------------

    FUNCTION countries_list
        RETURN VARCHAR2
    IS
        z_countries_list  VARCHAR2 (1024);
        z_countries_count PLS_INTEGER;
        l_params          logger_service.logger.tab_param;
        l_step            VARCHAR2 (100);
    BEGIN
        FOR i IN 1 .. smgs.participant.count
        LOOP
            l_step :=
                'FOR smgs.participant '
                || i;

            IF z_countries_list IS NULL
            THEN
                z_countries_list  := smgs.participant (i).state;
                z_countries_count := 1;
            ELSIF instr (smgs.participant (i).state
                        ,z_countries_list) = 0
            THEN
                z_countries_list  :=
                    z_countries_list
                    || ';'
                    || smgs.participant (i).state;
                z_countries_count := z_countries_count + 1;
            END IF;
        END LOOP;

        RETURN z_countries_list;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.append_param (l_params
                                               ,'z_countries_list'
                                               ,z_countries_list);
            logger_service.logger.append_param (l_params
                                               ,'z_countries_count'
                                               ,z_countries_count);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.countries_list'
                                            ,p_params => l_params);
            RETURN NULL;
    END countries_list;

    PROCEDURE correct_station_data (p_station IN OUT spv.smgs2_interface.t_edi_station)
    IS
        l_params logger_service.logger.tab_param;
    BEGIN
        IF p_station.code6 IS NULL
        THEN
            RETURN;
        END IF;

        IF    p_station.rw_admin IS NULL
           OR p_station.state IS NULL
        THEN
            SELECT id, kood, state
              INTO p_station.vjs_station_id, p_station.rw_admin, p_station.state
              FROM (  SELECT max (id) KEEP (DENSE_RANK FIRST ORDER BY priority)         id
                            ,max (kood) KEEP (DENSE_RANK FIRST ORDER BY priority)       kood
                            ,max (lyhend) KEEP (DENSE_RANK FIRST ORDER BY priority)     state
                        FROM (SELECT j.id, ra.kood, rk.lyhend, decode (p_station.rw_admin, ra.kood, 0, 2) AS priority
                                FROM jaamad                   j
                                    ,raudteed                 r
                                    ,raudteeadministratsioonid ra
                                    ,riigid                   rk
                               WHERE     j.kood6 = p_station.code6
                                     AND j.raudtee_kood = r.kood
                                     AND r.raudtadm_kood = ra.kood
                                     AND ra.riik_riik_id = rk.riik_id
                              UNION
                              -- Дархан-2 Mongolia 010249
                              SELECT NULL, '31', 'MN', 1 AS priority
                                FROM dual
                               WHERE p_station.code6 = '010249'
                              UNION
                              -- Славков Полудиновы ЛХС Poola 074286
                              SELECT NULL, '51', 'PL', 1 AS priority
                                FROM dual
                               WHERE p_station.code6 = '074286'
                              UNION
                              -- Malaszewicze Poola 074286
                              SELECT NULL, '51', 'PL', 1 AS priority
                                FROM dual
                               WHERE p_station.code6 = '040600'
                              UNION
                              -- Qingdao port Hiina 180890 (Operaili palve 06.06.2019)
                              SELECT NULL, '33', 'CN', 1 AS priority
                                FROM dual
                               WHERE p_station.code6 = '180890'
                              UNION
                              -- Manzhouli Hiina 578930 (Operaili palve 06.06.2019)
                              SELECT NULL, '33', 'CN', 1 AS priority
                                FROM dual
                               WHERE p_station.code6 = '578930'
                              UNION
                              SELECT NULL, to_char (ad.kod), to_char (s.mnemokod2), decode (p_station.rw_admin, ad.kod, 0, 3) AS priority
                                FROM ibmu.stan1 st
                                    ,ibmu.adm   ad
                                    ,ibmu.strana s
                               WHERE     st.adm_id = ad.adm_id
                                     AND st.cor_tip <> 'D'
                                     AND s.kod_iso = ad.kod_iso
                                     AND st.kod = p_station.code6
                                     AND st.date_nd <= sysdate
                                     AND st.date_kd > sysdate)
                    ORDER BY 1 NULLS FIRST)
             WHERE rownum = 1;
        END IF;
    EXCEPTION
        WHEN no_data_found
        THEN
            add_message (p_message        => replace (sass.get_tekst_in_lang (6530
                                                                             ,NULL
                                                                             ,v ('APP_USER'))
                                                     ,'%1'
                                                     ,p_station.code6)
                        ,p_realm          => 'error'
                        ,p_code           => -20000
                        ,p_www_tekstid_id => 6530
                        ,p_replacement1   => p_station.code6);
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_station.code6'
                                               ,p_station.code6);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.correct_station_data'
                                            ,p_params => l_params);
    END correct_station_data;

    PROCEDURE split_text_into_smgs (io_smgs     IN OUT smgs2_interface.t_smgs
                                   ,in_text     IN     VARCHAR2 DEFAULT NULL
                                   ,in_case     IN     VARCHAR2 DEFAULT NULL
                                   ,in_role     IN     VARCHAR2 DEFAULT NULL
                                   ,in_index    IN     PLS_INTEGER DEFAULT 0
                                   ,in_length   IN     PLS_INTEGER DEFAULT 350
                                   ,in_loop_max IN     PLS_INTEGER DEFAULT 9)
    IS
        l_tekst  VARCHAR2 (32767);
        l_idx    PLS_INTEGER;
        l_params logger_service.logger.tab_param;
    BEGIN
        l_tekst := in_text;

        CASE upper (in_case)
            WHEN 'GOODS.DESCRIPTION_TEXT'
            THEN
                FOR i IN 1 .. in_loop_max
                LOOP
                    io_smgs.goods (in_index).description_text.extend;
                    l_idx                                                       := io_smgs.goods (in_index).description_text.count;
                    io_smgs.goods (in_index).description_text (l_idx).smgs_role := in_role;
                    io_smgs.goods (in_index).description_text (l_idx).text      :=
                        substr (l_tekst
                               ,1
                               ,in_length);
                    EXIT WHEN nvl (length (l_tekst), 0) < in_length + 1;
                    l_tekst                                                     :=
                        substr (l_tekst
                               ,in_length + 1);
                END LOOP;
            WHEN 'GOODS.NAME_COMMENT'
            THEN
                FOR i IN 1 .. in_loop_max
                LOOP
                    io_smgs.goods (in_index).name_comment.extend;
                    l_idx                                                   := io_smgs.goods (in_index).name_comment.count;
                    io_smgs.goods (in_index).name_comment (l_idx).smgs_role := in_role;
                    io_smgs.goods (in_index).name_comment (l_idx).text      :=
                        substr (l_tekst
                               ,1
                               ,in_length);
                    EXIT WHEN nvl (length (l_tekst), 0) < in_length + 1;
                    l_tekst                                                 :=
                        substr (l_tekst
                               ,in_length + 1);
                END LOOP;
            ELSE
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'in_text IN first 30 chars'
                                                   ,substr (in_text
                                                           ,1
                                                           ,30));
                logger_service.logger.append_param (l_params
                                                   ,'in_case IN'
                                                   ,in_case);
                logger_service.logger.append_param (l_params
                                                   ,'in_role IN'
                                                   ,in_role);
                logger_service.logger.log_error (p_text   => 'Unknown in_case'
                                                ,p_scope  => 'spv.smgs2_validate.split_text_into_smgs'
                                                ,p_params => l_params);
        END CASE;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'in_text IN first 30 chars'
                                               ,substr (in_text
                                                       ,1
                                                       ,30));
            logger_service.logger.append_param (l_params
                                               ,'in_case IN'
                                               ,in_case);
            logger_service.logger.append_param (l_params
                                               ,'in_role IN'
                                               ,in_role);
            logger_service.logger.append_param (l_params
                                               ,'in_index IN'
                                               ,in_index);
            logger_service.logger.append_param (l_params
                                               ,'in_length IN'
                                               ,in_length);
            logger_service.logger.append_param (l_params
                                               ,'in_loop_max IN'
                                               ,in_loop_max);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.smgs2_validate.split_text_into_smgs'
                                            ,p_params => l_params);
    END split_text_into_smgs;

    PROCEDURE split_text_into_db (in_smgs     IN smgs2_interface.t_smgs
                                 ,in_text     IN VARCHAR2 DEFAULT NULL
                                 ,in_case     IN VARCHAR2 DEFAULT NULL
                                 ,in_role     IN VARCHAR2 DEFAULT NULL
                                 ,in_id       IN VARCHAR2 DEFAULT NULL
                                 ,in_length   IN PLS_INTEGER DEFAULT 350
                                 ,in_loop_max IN PLS_INTEGER DEFAULT 9)
    IS
        l_tekst  VARCHAR2 (32767);
        l_params logger_service.logger.tab_param;
    BEGIN
        l_tekst := in_text;

        CASE upper (in_case)
            WHEN 'GOODS.DESCRIPTION'
            THEN
                FOR i IN 1 .. in_loop_max
                LOOP
                    INSERT INTO edifact.tekst (sonum_id
                                              ,kaup_id
                                              ,tunnus
                                              ,tekst
                                              )
                         VALUES (in_smgs.edi_id
                                ,in_id
                                ,in_role
                                ,remove_line_break (substr (l_tekst
                                                           ,1
                                                           ,in_length))
                                );

                    EXIT WHEN nvl (length (l_tekst), 0) < in_length + 1;
                    l_tekst :=
                        substr (l_tekst
                               ,in_length + 1);
                END LOOP;
            ELSE
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'in_text IN first 30 chars'
                                                   ,substr (in_text
                                                           ,1
                                                           ,30));
                logger_service.logger.append_param (l_params
                                                   ,'in_case IN'
                                                   ,in_case);
                logger_service.logger.append_param (l_params
                                                   ,'in_role IN'
                                                   ,in_role);
                logger_service.logger.log_error (p_text   => 'Unknown in_case'
                                                ,p_scope  => 'spv.smgs2_validate.split_text_into_db'
                                                ,p_params => l_params);
        END CASE;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'in_text IN first 30 chars'
                                               ,substr (in_text
                                                       ,1
                                                       ,30));
            logger_service.logger.append_param (l_params
                                               ,'in_case IN'
                                               ,in_case);
            logger_service.logger.append_param (l_params
                                               ,'in_role IN'
                                               ,in_role);
            logger_service.logger.append_param (l_params
                                               ,'in_id IN'
                                               ,in_id);
            logger_service.logger.append_param (l_params
                                               ,'in_length IN'
                                               ,in_length);
            logger_service.logger.append_param (l_params
                                               ,'in_loop_max IN'
                                               ,in_loop_max);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.smgs2_validate.split_text_into_db'
                                            ,p_params => l_params);
    END split_text_into_db;

    PROCEDURE combine_collections (p_smgs    IN OUT smgs2_interface.t_smgs
                                  ,p_message IN OUT tb_validation_message)
    IS
        z_cont      smgs2_interface.tb_edi_container;
        z_cindex    PLS_INTEGER;
        z_windex    PLS_INTEGER;
        z_pindex    PLS_INTEGER;
        l_params    logger_service.logger.tab_param;
        l_step      VARCHAR2 (300);
        l_index     PLS_INTEGER;
        l_text      VARCHAR2 (4000);
        l_text_role VARCHAR2 (3);
    BEGIN
        l_step               := 'begin';
        -- init
        p_smgs.document      := smgs2_interface.tb_edi_document ();
        p_smgs.station       := smgs2_interface.tb_edi_station ();
        p_smgs.participant   := smgs2_interface.tb_edi_participant ();
        p_smgs.goods         := smgs2_interface.tb_edi_goods ();
        p_smgs.wagon         := smgs2_interface.tb_edi_wagon ();
        p_smgs.text          := smgs2_interface.tb_edi_text ();
        p_smgs.reference     := smgs2_interface.tb_edi_reference ();
        -- border needed in save_document
        p_smgs.border        := smgs2_interface.tb_border ();

        p_smgs.carrier_code4 := vjs_guard.get_user_carrier_code2 (nvl (v ('APP_USER'), user));

        message              := tb_validation_message ();

        -- common data
        l_step               := 'common data';

        SELECT CASE p_smgs.dokum_kood
                   WHEN 'ZPN'
                   THEN
                       to_date (c001
                               ,'dd.mm.yyyy hh24:mi')
                   ELSE
                       to_date (c001
                               ,'dd.mm.yyyy')
               END                          created_at
              ,substr (c002
                      ,1
                      ,6)                   status
              ,substr (c003
                      ,1
                      ,35)                  smgs_number
              ,substr (c004
                      ,1
                      ,35)                  contract_nr
              ,substr (c007
                      ,1
                      ,3)                   who_loaded
              ,substr (c008
                      ,1
                      ,3)                   smgs_type
              ,substr (c009
                      ,1
                      ,6)                   s_station_code
              ,substr (c010
                      ,1
                      ,70)                  s_station_name
              ,substr (c011
                      ,1
                      ,2)                   s_station_rwadmin
              ,substr (c012
                      ,1
                      ,6)                   d_station_code
              ,substr (c013
                      ,1
                      ,70)                  d_station_name
              ,substr (c014
                      ,1
                      ,2)                   d_station_rwadmin
              ,substr (c015
                      ,1
                      ,4)                   sender_code
              ,substr (c016
                      ,1
                      ,175)                 sender_nimi
              ,substr (c017
                      ,1
                      ,4)                   recipient_code
              ,substr (c018
                      ,1
                      ,175)                 recipient_nimi
              ,substr (c020
                      ,1
                      ,1)                   saad_funk_kood
              ,trim (v ('P'
                        || v ('APP_PAGE_ID')
                        || '_SONUM_ID'))    edi_id
              ,trim (v ('P'
                        || v ('APP_PAGE_ID')
                        || '_SOURCE'))      data_source
              ,trim (substr (c023
                            ,1
                            ,18))           mrn_number
              ,substr (c024
                      ,1
                      ,1)                   sn_in_out
          INTO p_smgs.created_at
              ,p_smgs.status
              ,p_smgs.smgs_number
              ,p_smgs.contract_nr
              ,p_smgs.who_loaded
              ,p_smgs.smgs_type
              ,p_smgs.s_station_code
              ,p_smgs.s_station_name
              ,p_smgs.s_station_rwadmin
              ,p_smgs.d_station_code
              ,p_smgs.d_station_name
              ,p_smgs.d_station_rwadmin
              ,p_smgs.sender_code
              ,p_smgs.sender_nimi
              ,p_smgs.recipient_code
              ,p_smgs.recipient_nimi
              ,p_smgs.saad_funk_kood
              ,p_smgs.edi_id
              ,p_smgs.data_source
              ,p_smgs.mrn_number
              ,p_smgs.sn_in_out
          FROM apex_collections
         WHERE collection_name = smgs2_interface.common_coll_name;

        -- define smgs type
        l_step               := 'define smgs type';

        IF     p_smgs.smgs_type IS NULL
           AND apex_collection.collection_exists (smgs2_interface.containers_coll_name)
        THEN
            IF apex_collection.collection_member_count (smgs2_interface.containers_coll_name) > 0
            THEN
                -- konteineri saadetis
                p_smgs.smgs_type := 4;
            END IF;
        END IF;

        IF p_smgs.smgs_type IS NULL
        THEN
            -- vagunite saadetis
            p_smgs.smgs_type := 2;
        END IF;

        l_step               := 'update_member_attribute common_coll_name';
        apex_collection.update_member_attribute (p_collection_name => smgs2_interface.common_coll_name
                                                ,p_seq             => '1'
                                                ,p_attr_number     => '8'
                                                ,p_attr_value      => p_smgs.smgs_type);

        -- stations
        l_step               := 'stations';

          SELECT substr (c001
                        ,1
                        ,6)
                ,substr (c002
                        ,1
                        ,6)
                ,substr (c003
                        ,1
                        ,70)
                ,substr (c004
                        ,1
                        ,3)
                ,substr (c005
                        ,1
                        ,4)
                ,substr (c006
                        ,1
                        ,2)
                ,substr (c007
                        ,1
                        ,2)
            BULK COLLECT INTO p_smgs.station
            FROM apex_collections
           WHERE collection_name = smgs2_interface.stations_coll_name
        ORDER BY decode (c004,  '5', 0,  '8', 1,  '17', 2,  '42', 3,  4)
                ,seq_id;

        FOR i IN 1 .. p_smgs.station.count
        LOOP
            l_step :=
                'FOR p_smgs.station '
                || i;
            correct_station_data (p_smgs.station (i));
        END LOOP;

        -- participants
        l_step               := 'participants';
        z_pindex             := 1;

        FOR i IN (  SELECT seq_id
                          ,substr (c012
                                  ,1
                                  ,35)     reg_code
                          ,substr (c002
                                  ,1
                                  ,175)    name
                          ,substr (c001
                                  ,1
                                  ,4)      code4
                          ,substr (c003
                                  ,1
                                  ,3)      smgs_role
                          ,substr (c004
                                  ,1
                                  ,35)     agent
                          ,substr (c005
                                  ,1
                                  ,2)      state
                          ,substr (c006
                                  ,1
                                  ,35)     city
                          ,substr (c007
                                  ,1
                                  ,140)    street
                          ,substr (c008
                                  ,1
                                  ,9)      zipcode
                          ,substr (c009
                                  ,1
                                  ,512)    telefon
                          ,substr (c010
                                  ,1
                                  ,512)    fax
                          ,substr (c011
                                  ,1
                                  ,512)    email
                          ,substr (c013
                                  ,1
                                  ,2)      rw_admin
                          ,substr (c014
                                  ,1
                                  ,256)    signature
                          ,substr (c015
                                  ,1
                                  ,3)      e_document
                          , -- for carrier. First station of region
                           substr (c016
                                  ,1
                                  ,6)      first_station_code
                          ,substr (c017
                                  ,1
                                  ,128)    first_station_name
                          , -- for carrier. Last station of region
                           substr (c018
                                  ,1
                                  ,6)      last_station_code
                          ,substr (c019
                                  ,1
                                  ,128)    last_station_name
                          , -- for role GS - link for role CA
                           c020            contract_number
                          ,c021            contract_date
                          ,c049            undertaker
                          ,c050            unique_key
                      FROM apex_collections
                     WHERE collection_name = smgs2_interface.participants_coll_name
                  ORDER BY decode (c003,  'CN', 0,  'CZ', 1,  'GS', 2,  'DCP', 3,  'CPD', 4,  'CA', 5,  6)
                          ,seq_id)
        LOOP
            l_step                                              :=
                'FOR participants_coll_name '
                || i.seq_id;
            p_smgs.participant.extend;

            --collect codes
            l_step                                              :=
                'FOR participants_coll_name '
                || i.seq_id
                || ' and collect codes';

            SELECT c002 code_type, c003 code_value
              BULK COLLECT INTO p_smgs.participant (z_pindex).codes
              FROM apex_collections
             WHERE     collection_name = smgs2_interface.participants_codes_coll_name
                   AND c001 = i.unique_key;

            l_step                                              :=
                'FOR participants_coll_name '
                || i.seq_id
                || ' and search OKPO code from participant codes';

            IF i.reg_code IS NULL
            THEN
                BEGIN
                    --search OKPO code from participant codes
                    SELECT c003     code_value
                      INTO p_smgs.participant (z_pindex).reg_code
                      FROM apex_collections
                     WHERE     collection_name = smgs2_interface.participants_codes_coll_name
                           AND c001 = i.seq_id
                           AND c002 = 'Z02';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_smgs.participant (z_pindex).reg_code := NULL;
                END;
            ELSE
                p_smgs.participant (z_pindex).reg_code := i.reg_code;
            END IF;

            l_step                                              :=
                'FOR participants_coll_name '
                || i.seq_id
                || ' and participant '
                || z_pindex;
            p_smgs.participant (z_pindex).name                  := i.name;
            p_smgs.participant (z_pindex).code4                 := i.code4;
            p_smgs.participant (z_pindex).smgs_role             := i.smgs_role;
            p_smgs.participant (z_pindex).agent                 := i.agent;
            p_smgs.participant (z_pindex).state                 := i.state;
            p_smgs.participant (z_pindex).city                  := i.city;
            p_smgs.participant (z_pindex).street                := i.street;
            p_smgs.participant (z_pindex).zipcode               := i.zipcode;
            p_smgs.participant (z_pindex).telefon               := i.telefon;
            p_smgs.participant (z_pindex).fax                   := i.fax;
            p_smgs.participant (z_pindex).email                 := i.email;

            p_smgs.participant (z_pindex).signature             := i.signature;
            p_smgs.participant (z_pindex).e_document            := i.e_document;

            p_smgs.participant (z_pindex).carrier_region        := smgs2_interface.tb_edi_station ();
            p_smgs.participant (z_pindex).parent_participant_id := i.undertaker;
            p_smgs.participant (z_pindex).participant_id        := i.unique_key;

            -- for undertaker save region
            l_step                                              :=
                'FOR participants_coll_name '
                || i.seq_id
                || ' and participant '
                || z_pindex
                || ' and for undertaker save region';

            IF i.first_station_code IS NOT NULL
            THEN
                p_smgs.participant (z_pindex).carrier_region.extend;
                p_smgs.participant (z_pindex).carrier_region (1).code6 := i.first_station_code;
                p_smgs.participant (z_pindex).carrier_region (1).name  := i.first_station_name;
                correct_station_data (p_smgs.participant (z_pindex).carrier_region (1));
                p_smgs.participant (z_pindex).carrier_region.extend;
                p_smgs.participant (z_pindex).carrier_region (2).code6 := i.last_station_code;
                p_smgs.participant (z_pindex).carrier_region (2).name  := i.last_station_name;
                correct_station_data (p_smgs.participant (z_pindex).carrier_region (2));
            END IF;

            p_smgs.participant (z_pindex).documents             := smgs2_interface.tb_edi_document ();

            -- for expeditor save contract
            l_step                                              :=
                'FOR participants_coll_name '
                || i.seq_id
                || ' and participant '
                || z_pindex
                || ' and for expeditor save contract';

            IF     i.contract_number IS NOT NULL
               AND p_smgs.participant (z_pindex).smgs_role = 'GS'
            THEN
                p_smgs.participant (z_pindex).documents.extend;
                p_smgs.participant (z_pindex).documents (p_smgs.participant (z_pindex).documents.count).docnumber := i.contract_number;
                p_smgs.participant (z_pindex).documents (p_smgs.participant (z_pindex).documents.count).created_at :=
                    to_date (i.contract_date
                            ,'dd.mm.yyyy');
            END IF;

            z_pindex                                            := z_pindex + 1;
        END LOOP;

        -- texts
        l_step               := 'texts';

        SELECT c001, c002, c003
          BULK COLLECT INTO p_smgs.text
          FROM apex_collections
         WHERE     collection_name = smgs2_interface.texts_coll_name
               AND c002 IN ('AAO'
                           ,'ICN'
                           ,'AAH'
                           ,'IRP'
                           ,'BLR'
                           ,'AEA');

        -- apex collection members with role TRA are fragmented (length varies from 0 to 350)
        -- so defragmentation needed to let only last member to have length < 350;
        -- apex collection member with role DCL length varies from 0 to 1050 (see parameter IFTMIN_SENDER_STATEMENT_MAX);
        -- FOR i IN 1 .. 90 looping added for future text roles if member length can be > 350;

        FOR r_text_role IN (SELECT 'TRA' text_role FROM dual
                            UNION
                            SELECT 'DCL' text_role FROM dual)
        LOOP
            l_text_role := r_text_role.text_role;

            l_step      :=
                'text '
                || l_text_role;
            l_text      := NULL;

            FOR r_text IN (  SELECT c001, c002, c003
                               FROM apex_collections
                              WHERE     collection_name = smgs2_interface.texts_coll_name
                                    AND c002 = l_text_role
                           ORDER BY seq_id)
            LOOP
                l_text :=
                    l_text
                    || r_text.c001;

                FOR i IN 1 .. 90
                LOOP
                    IF nvl (length (l_text), 0) >= 350
                    THEN
                        p_smgs.text.extend;
                        l_index                         := p_smgs.text.count;
                        p_smgs.text (l_index).smgs_role := r_text.c002;
                        p_smgs.text (l_index).text      :=
                            substr (l_text
                                   ,1
                                   ,350);
                        l_text                          :=
                            substr (l_text
                                   ,351);
                    END IF;

                    EXIT WHEN nvl (length (l_text), 0) < 350;
                END LOOP;
            END LOOP;

            IF nvl (length (l_text), 0) > 0
            THEN
                FOR i IN 1 .. 90
                LOOP
                    p_smgs.text.extend;
                    l_index                         := p_smgs.text.count;
                    p_smgs.text (l_index).smgs_role := l_text_role;
                    p_smgs.text (l_index).text      :=
                        substr (l_text
                               ,1
                               ,350);
                    EXIT WHEN nvl (length (l_text), 0) < 351;
                    l_text                          :=
                        substr (l_text
                               ,351);
                END LOOP;
            END IF;
        END LOOP;

        -- goods
        l_step               := 'goods';

        -- ORDER BY tonumber (c001) - to bulk collect by goods.c001 - needed at least for packages
        FOR goods IN (  SELECT *
                          FROM apex_collections
                         WHERE collection_name = smgs2_interface.goods_coll_name
                      ORDER BY tonumber (c001))
        LOOP
            p_smgs.goods.extend;
            p_smgs.goods (p_smgs.goods.count).dangerous_goods_stamps := spv.smgs2_interface.tb_dangerous_goods_stamp ();

            --package
            l_step                                     :=
                'goods package with goods.c001 '
                || goods.c001;

            SELECT substr (c002
                          ,1
                          ,17)
                  ,substr (c003
                          ,1
                          ,2)
                  ,substr (c004
                          ,1
                          ,8)
                  -- in smgs order differs from collection
                  ,substr (c006
                          ,1
                          ,8)
                  ,substr (c005
                          ,1
                          ,35)
                  -- element_index
                  ,substr (c007
                          ,1
                          ,1)
                  -- positsioon
                  ,substr (c008
                          ,1
                          ,3)
              BULK COLLECT INTO p_smgs.goods (goods.c001).package
              FROM apex_collections
             WHERE     collection_name = smgs2_interface.packages_coll_name
                   AND c001 = goods.c050;

            --label
            l_step                                     :=
                'goods label with goods.c001 '
                || goods.c001;

            SELECT c002, c003
              BULK COLLECT INTO p_smgs.goods (goods.c001).label
              FROM apex_collections
             WHERE     collection_name = smgs2_interface.labels_coll_name
                   AND c001 = goods.c050;

            -- Dangerous goods STAMPS collection
            l_step                                     :=
                'goods Dangerous goods STAMPS collection with goods.c001 '
                || goods.c001;

            IF apex_collection.collection_exists (smgs2_interface.goods_stamps_coll_name)
            THEN
                -- seq_id as dangerous_goods_stamps.position seems to be not used atm
                SELECT seq_id, c002
                  BULK COLLECT INTO p_smgs.goods (goods.c001).dangerous_goods_stamps
                  FROM apex_collections
                 WHERE     collection_name = smgs2_interface.goods_stamps_coll_name
                       AND c001 = goods.c050;
            END IF;

            -- goods
            l_step                                     :=
                'goods in goods with goods.c001 '
                || goods.c001;
            p_smgs.goods (goods.c001).position         := goods.c001;
            p_smgs.goods (goods.c001).gng              :=
                substr (goods.c002
                       ,1
                       ,35);
            p_smgs.goods (goods.c001).etsng            :=
                substr (goods.c003
                       ,1
                       ,35);
            --p_smgs.goods (goods.c001).client_weight := SUBSTR (goods.c004, 1, 18);
            p_smgs.goods (goods.c001).railway_weight   :=
                substr (goods.c005
                       ,1
                       ,18);
            p_smgs.goods (goods.c001).danger_code      :=
                substr (goods.c006
                       ,1
                       ,35);
            p_smgs.goods (goods.c001).danger_crash_card :=
                substr (goods.c007
                       ,1
                       ,7);
            p_smgs.goods (goods.c001).danger_un_code   :=
                substr (goods.c008
                       ,1
                       ,4);
            p_smgs.goods (goods.c001).name             :=
                substr (goods.c009
                       ,1
                       ,350);
            p_smgs.goods (goods.c001).danger_name      :=
                substr (goods.c010
                       ,1
                       ,350);
            p_smgs.goods (goods.c001).danger_class     :=
                substr (goods.c011
                       ,1
                       ,35);
            p_smgs.goods (goods.c001).danger_sign      :=
                substr (goods.c012
                       ,1
                       ,35);
            p_smgs.goods (goods.c001).danger_packing_group :=
                substr (goods.c013
                       ,1
                       ,3);
            p_smgs.goods (goods.c001).state_dispatch   :=
                substr (goods.c014
                       ,1
                       ,3);
            p_smgs.goods (goods.c001).state_destination :=
                substr (goods.c015
                       ,1
                       ,3);
            -- description_text needed in save_document
            p_smgs.goods (goods.c001).description_text := smgs2_interface.tb_edi_text ();
            p_smgs.goods (goods.c001).description_text.extend;
            -- goods name
            p_smgs.goods (goods.c001).description_text (1).text :=
                substr (goods.c009
                       ,1
                       ,350);
        END LOOP;

        --wagons
        l_step               := 'wagons';
        z_windex             := 1;

        FOR wagon IN (  SELECT *
                          FROM apex_collections
                         WHERE collection_name = smgs2_interface.wagons_coll_name
                      ORDER BY seq_id)
        LOOP
            p_smgs.wagon.extend;

            --lead
            l_step                               :=
                'wagons with z_windex '
                || z_windex
                || ' and lead with wagon.c001 '
                || wagon.c001;

            SELECT substr (c002
                          ,1
                          ,256)
                  ,substr (c003
                          ,1
                          ,3)
                  ,substr (c004
                          ,1
                          ,5)
                  ,substr (c005
                          ,1
                          ,6)
              BULK COLLECT INTO p_smgs.wagon (z_windex).lead
              FROM apex_collections
             WHERE     collection_name = smgs2_interface.wagon_leads_coll_name
                   AND c001 = wagon.c001;

            --containers
            l_step                               :=
                'wagons with z_windex '
                || z_windex
                || ' and containers with wagon.c001 '
                || wagon.c001;
            z_cont                               := smgs2_interface.tb_edi_container ();
            z_cindex                             := 0;

            FOR cont IN (  SELECT *
                             FROM apex_collections
                            WHERE     collection_name = smgs2_interface.containers_coll_name
                                  AND c001 = wagon.c001
                         ORDER BY c002)
            LOOP
                z_cont.extend;
                z_cindex                   := z_cont.count;

                --lead
                l_step                     :=
                    'wagons with z_windex '
                    || z_windex
                    || ' and containers with wagon.c001 '
                    || wagon.c001
                    || ' and with z_cindex '
                    || z_cindex
                    || ' and lead with container number cont.c003 '
                    || cont.c003;

                SELECT substr (c002
                              ,1
                              ,256)
                      ,substr (c003
                              ,1
                              ,3)
                      ,substr (c004
                              ,1
                              ,2)
                      ,substr (c005
                              ,1
                              ,6)
                  BULK COLLECT INTO z_cont (z_cindex).lead
                  FROM apex_collections
                 WHERE     collection_name = smgs2_interface.container_leads_coll_name
                       AND c001 = cont.c003;

                -- cont.c003 - container number

                z_cont (z_cindex).position := z_cindex;
                z_cont (z_cindex).container_nr :=
                    substr (cont.c003
                           ,1
                           ,17);
                z_cont (z_cindex).rw_admin :=
                    substr (cont.c004
                           ,1
                           ,2);
                z_cont (z_cindex).net_weight :=
                    substr (cont.c005
                           ,1
                           ,6);
                z_cont (z_cindex).length   :=
                    substr (cont.c006
                           ,1
                           ,2);
                z_cont (z_cindex).goods_weight :=
                    substr (cont.c007
                           ,1
                           ,6);
                z_cont (z_cindex).ownership_form :=
                    substr (cont.c008
                           ,1
                           ,1);
                z_cont (z_cindex).type     :=
                    substr (cont.c009
                           ,1
                           ,2);
                z_cindex                   := z_cindex + 1;
            END LOOP;

            l_step                               :=
                'wagons with z_windex '
                || z_windex
                || ' and p_smgs.wagon (z_windex)';
            p_smgs.wagon (z_windex).container    := z_cont;

            -- equipments (non-containers) needed in save_document
            p_smgs.wagon (z_windex).equipment    := smgs2_interface.tb_edi_equipment ();

            p_smgs.wagon (z_windex).position     := z_windex;

            p_smgs.wagon (z_windex).wagon_nr     :=
                substr (wagon.c001
                       ,1
                       ,8);

            p_smgs.wagon (z_windex).rw_admin     :=
                substr (wagon.c002
                       ,1
                       ,2);

            p_smgs.wagon (z_windex).net_weight   := get_number (wagon.c003);

            p_smgs.wagon (z_windex).capacity     := get_number (wagon.c004);

            p_smgs.wagon (z_windex).axis         := get_number (wagon.c005);

            p_smgs.wagon (z_windex).goods_weight := get_number (wagon.c006);

            p_smgs.wagon (z_windex).kalibr_code  :=
                substr (wagon.c009
                       ,1
                       ,3);

            p_smgs.wagon (z_windex).owner_name   :=
                substr (wagon.c010
                       ,1
                       ,35);

            p_smgs.wagon (z_windex).provider     :=
                substr (wagon.c011
                       ,1
                       ,1);

            p_smgs.wagon (z_windex).prev_etsng   :=
                substr (wagon.c012
                       ,1
                       ,6);

            p_smgs.wagon (z_windex).prev_gng     :=
                substr (wagon.c013
                       ,1
                       ,12);

            p_smgs.wagon (z_windex).prev_desc    :=
                substr (wagon.c014
                       ,1
                       ,350);
            p_smgs.wagon (z_windex).notes        :=
                substr (wagon.c015
                       ,1
                       ,350);
            p_smgs.wagon (z_windex).prev_danger_desc :=
                substr (wagon.c016
                       ,1
                       ,350);

            z_windex                             := z_windex + 1;
        END LOOP;

        -- documents
        l_step               := 'documents';

        FOR docs IN (SELECT c001 role, c002 docnumber, c003 created_at, c004 format, c005 doc_name, c006 rw_admin, n001 doc_count
                       FROM apex_collections
                      WHERE collection_name = smgs2_interface.documents_coll_name)
        LOOP
            l_step                                            :=
                'documents with docs.docnumber '
                || docs.docnumber;
            p_smgs.document.extend;
            p_smgs.document (p_smgs.document.count).code      := docs.role;
            p_smgs.document (p_smgs.document.count).docnumber := docs.docnumber;
            p_smgs.document (p_smgs.document.count).created_at :=
                to_date (docs.created_at
                        ,'dd.mm.yyyy');
            p_smgs.document (p_smgs.document.count).doc_type  := docs.format;
            p_smgs.document (p_smgs.document.count).doc_name  := docs.doc_name;
            p_smgs.document (p_smgs.document.count).rw_admin  := docs.rw_admin;
            p_smgs.document (p_smgs.document.count).doc_count := docs.doc_count;
        END LOOP;

        p_message            := message;
    EXCEPTION
        WHEN OTHERS
        THEN
            add_message (p_message        => get_tekst (6302)
                        ,p_realm          => 'error'
                        ,p_code           => sqlcode
                        ,p_www_tekstid_id => 6302);
            l_params  := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.combine_collections'
                                            ,p_params => l_params);
            p_message := message;
    END combine_collections;

    PROCEDURE validate_texts
    IS
        l_params logger_service.logger.tab_param;
        l_step   VARCHAR2 (300);
    BEGIN
        FOR i IN 1 .. smgs.text.count
        LOOP
            IF     length (smgs.text (i).text) > 350
               AND smgs.text (i).smgs_role IN ('AEA'
                                              ,'BLR'
                                              ,'DCL'
                                              ,'TRA')
            THEN
                l_step :=
                    'FOR smgs.text '
                    || i
                    || ' with smgs_role '
                    || smgs.text (i).smgs_role;
                add_message (p_message        => nvl (vjs.vjs_tekstid$.get_tekst (p_kood     => 'TEXT_LENGTH_OVER_LIMIT'
                                                                                 ,p_kontekst => 'SAATELEHTEDE_HALDUS'
                                                                                 ,p_keel     => get_kasutaja_keel ()
                                                                                 ,p_par1     => smgs.smgs_number
                                                                                 ,p_par2     => smgs.text (i).smgs_role
                                                                                 ,p_par3     => '350')
                                                     ,'Sõnumi nr '
                                                      || smgs.smgs_number
                                                      || ' tekst rolliga '
                                                      || smgs.text (i).smgs_role
                                                      || ' pikkus on üle lubatud 350 !')
                            ,p_realm          => 'warning'
                            ,p_code           => '-20000'
                            ,p_www_tekstid_id => NULL);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            add_message (p_message        => get_tekst (6302)
                        ,p_realm          => 'error'
                        ,p_code           => sqlcode
                        ,p_www_tekstid_id => 6302);
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.validate_texts'
                                            ,p_params => l_params);
    END validate_texts;

    FUNCTION get_edi_id_by_smgs_number (p_smgs_number IN edifact.sonum.saadetise_nr%TYPE)
        RETURN edifact.sonum.id%TYPE
    IS
        result   edifact.sonum.id%TYPE;
        l_params logger_service.logger.tab_param;
    BEGIN
        SELECT max (id)
                   KEEP (DENSE_RANK LAST ORDER BY
                                             sn_kuupaev
                                            ,muutmise_kuupaev
                                            ,loomise_kuupaev)    AS edi_id
          INTO result
          FROM edifact.sonum
         WHERE saadetise_nr = p_smgs_number;

        RETURN result;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_smgs_number IN'
                                               ,p_smgs_number);
            logger_service.logger.append_param (l_params
                                               ,'RETURN result'
                                               ,result);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.get_edi_id_by_smgs_number'
                                            ,p_params => l_params);
            RETURN NULL;
    END get_edi_id_by_smgs_number;

    PROCEDURE validate_references
    IS
        l_params logger_service.logger.tab_param;
    BEGIN
        --     originalSMGSNumber
        IF smgs.transportationstatus.is_reforwarding = 1
        THEN
            IF smgs.transportationstatus.originalsmgsnumber IS NULL
            THEN
                add_message (p_message        => sass.get_tekst_in_lang (6588
                                                                        ,NULL
                                                                        ,v ('APP_USER'))
                            ,p_realm          => 'error'
                            ,p_www_tekstid_id => 6588);
            ELSE
                smgs.transportationstatus.originalsmgs_edi_id := edifact.get_edi_id_by_smgs_number (smgs.transportationstatus.originalsmgsnumber);

                IF smgs.transportationstatus.originalsmgs_edi_id IS NULL
                THEN
                    add_message (p_message        => sass.get_tekst_in_lang (6589
                                                                            ,NULL
                                                                            ,v ('APP_USER'))
                                ,p_realm          => 'error'
                                ,p_www_tekstid_id => 6589
                                ,p_replacement1   => smgs.smgs_number
                                ,p_replacement2   => smgs.transportationstatus.originalsmgsnumber);
                END IF;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            add_message (p_message        => get_tekst (6302)
                        ,p_realm          => 'error'
                        ,p_code           => sqlcode
                        ,p_www_tekstid_id => 6302);
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.validate_references'
                                            ,p_params => l_params);
    END validate_references;

    PROCEDURE validate_stations
    IS
        z_sender_station_count PLS_INTEGER := 0;
        z_destin_station_count PLS_INTEGER := 0;
        z_border_station_count PLS_INTEGER := 0;
        z_count                PLS_INTEGER;
        l_params               logger_service.logger.tab_param;
        l_step                 VARCHAR2 (300);

        FUNCTION is_border_station (p_code6 IN VARCHAR2)
            RETURN BOOLEAN
        IS
            z_count NUMBER;
        BEGIN
            -- is it border code
            SELECT count (0)
              INTO z_count
              FROM ibmu.stik_punkt  st
                  ,ibmu.stan        s
             WHERE     s.kod = p_code6
                   AND (   st.stan1_ex_id = s.stan_id
                        OR st.stan2_ex_id = s.stan_id);

            IF     z_count = 0
               AND p_code6 != '066118' /* Operaile palve 06.06.2019 Manzhouli Hiina*/
               AND p_code6 != '578930'
            THEN
                RETURN FALSE;
            END IF;

            RETURN TRUE;
        EXCEPTION
            WHEN OTHERS
            THEN
                add_message (p_message        => get_tekst (6302)
                            ,p_realm          => 'error'
                            ,p_code           => sqlcode
                            ,p_www_tekstid_id => 6302);
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'p_code6 IN'
                                                   ,p_code6);
                logger_service.logger.append_param (l_params
                                                   ,'INTO z_count'
                                                   ,z_count);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.validate_stations - FUNCTION is_border_station'
                                                ,p_params => l_params);
        END is_border_station;

        FUNCTION get_undertaker_for_station (p_station IN smgs2_interface.t_edi_station)
            RETURN VARCHAR2
        IS
        BEGIN
            FOR i IN 1 .. smgs.participant.count
            LOOP
                l_step :=
                    'FOR smgs.participant '
                    || i;

                /* search by carriers regions */
                BEGIN
                    IF smgs.participant (i).smgs_role = 'CA'
                    THEN
                        FOR j IN 1 .. smgs.participant (i).carrier_region.count
                        LOOP
                            l_step :=
                                'FOR smgs.participant '
                                || i
                                || ' and FOR carrier_region '
                                || j;

                            IF smgs.participant (i).carrier_region (j).code6 = p_station.code6
                            THEN
                                RETURN smgs.participant (i).name;
                                debug_message (' * Found undertaker '
                                               || smgs.participant (i).name
                                               || ' for station '
                                               || p_station.name
                                               || ' ('
                                               || p_station.code6
                                               || ')');
                            END IF;
                        END LOOP;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_params := logger_service.logger.gc_empty_tab_param;
                        logger_service.logger.append_param (l_params
                                                           ,'l_step'
                                                           ,l_step);
                        logger_service.logger.append_param (l_params
                                                           ,'RETURN smgs.participant (i).name'
                                                           ,smgs.participant (i).name);
                        logger_service.logger.log_error (p_text   => sqlerrm
                                                        ,p_scope  => 'spv.'
                                                                    || $$plsql_unit
                                                                    || '.validate_stations - FUNCTION get_undertaker_for_station - search by carriers regions'
                                                        ,p_params => l_params);
                END;

                /* search by state */
                IF     smgs.participant (i).smgs_role = 'CA'
                   AND smgs.participant (i).state = p_station.state
                THEN
                    RETURN smgs.participant (i).name;
                END IF;
            END LOOP;

            RETURN NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.validate_stations - FUNCTION get_undertaker_for_station'
                                                ,p_params => l_params);
                RETURN NULL;
        END get_undertaker_for_station;
    BEGIN
        FOR i IN 1 .. smgs.station.count
        LOOP
            l_step :=
                'FOR smgs.station '
                || i;

            BEGIN
                correct_station_data (smgs.station (i));
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_params := logger_service.logger.gc_empty_tab_param;
                    logger_service.logger.append_param (l_params
                                                       ,'l_step'
                                                       ,l_step);
                    logger_service.logger.log_error (p_text   => sqlerrm
                                                    ,p_scope  => 'spv.'
                                                                || $$plsql_unit
                                                                || '.validate_stations - correct_station_data (smgs.station (i))'
                                                    ,p_params => l_params);
                    RETURN;
            END;

            l_step :=
                'IF smgs.station (i).smgs_role with smgs.station '
                || i;

            IF smgs.station (i).smgs_role = '5'
            THEN
                z_sender_station_count := z_sender_station_count + 1;
            END IF;

            IF smgs.station (i).smgs_role = '8'
            THEN
                z_destin_station_count := z_destin_station_count + 1;
            END IF;

            IF smgs.station (i).smgs_role = '17'
            THEN
                IF NOT is_border_station (smgs.station (i).code6)
                THEN
                    add_message (p_message        => replace (sass.get_tekst_in_lang (6535
                                                                                     ,NULL
                                                                                     ,v ('APP_USER'))
                                                             ,'%1'
                                                             ,smgs.station (i).code6)
                                ,p_realm          => 'error'
                                ,p_www_tekstid_id => 6535
                                ,p_replacement1   => smgs.station (i).code6);
                END IF;

                -- exclusion for XML-related IFTMIN_PN
                IF    nvl (smgs.dokum_kood, 'x') <> 'ZPN'
                   OR nvl (smgs.status, 'x') = 'PORTAL'
                THEN
                    z_border_station_count := z_border_station_count + 1;
                END IF;
            END IF;

            IF smgs.station (i).smgs_role = '42'
            THEN
                IF NOT is_border_station (smgs.station (i).code6)
                THEN
                    add_message (p_message        => replace (sass.get_tekst_in_lang (6535
                                                                                     ,NULL
                                                                                     ,v ('APP_USER'))
                                                             ,'%1'
                                                             ,smgs.station (i).code6)
                                ,p_realm          => 'error'
                                ,p_www_tekstid_id => 6535
                                ,p_replacement1   => smgs.station (i).code6);
                END IF;

                IF nvl (smgs.dokum_kood, 'x') = 'ZPN' -- for IFTMIN_PN
                THEN
                    z_border_station_count := z_border_station_count + 1;
                END IF;
            END IF;

            IF get_undertaker_for_station (smgs.station (i)) IS NULL
            THEN
                add_message (p_message        => replace (sass.get_tekst_in_lang (6587
                                                                                 ,NULL
                                                                                 ,v ('APP_USER'))
                                                         ,'%1'
                                                         ,smgs.station (i).name
                                                          || ' ('
                                                          || smgs.station (i).code6)
                                                || ')'
                            ,p_realm          => 'error'
                            ,p_www_tekstid_id => 6587
                            ,p_replacement1   => smgs.station (i).name
                                                || ' ('
                                                || smgs.station (i).code6
                                                || ')');
            END IF;
        END LOOP;

        l_step := 'IF z_sender_station_count < 1';

        IF z_sender_station_count < 1
        THEN
            add_message (p_message        => sass.get_tekst_in_lang (6146
                                                                    ,NULL
                                                                    ,v ('APP_USER'))
                        ,p_realm          => 'error'
                        ,p_www_tekstid_id => 6146);
        END IF;

        l_step := 'IF z_destin_station_count < 1';

        IF z_destin_station_count < 1
        THEN
            add_message (p_message        => sass.get_tekst_in_lang (6147
                                                                    ,NULL
                                                                    ,v ('APP_USER'))
                        ,p_realm          => 'error'
                        ,p_www_tekstid_id => 6147);
        END IF;

        l_step := 'IF z_border_station_count < 1';

        IF z_border_station_count < 1
        THEN
            add_message (p_message        => sass.get_tekst_in_lang (6148
                                                                    ,NULL
                                                                    ,v ('APP_USER'))
                        ,p_realm          => 'error'
                        ,p_www_tekstid_id => 6148);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            add_message (p_message        => get_tekst (6302)
                        ,p_realm          => 'error'
                        ,p_code           => '-20000'
                        ,p_www_tekstid_id => 6302);
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.validate_stations'
                                            ,p_params => l_params);
    END validate_stations;

    PROCEDURE validate_goods
    IS
        z_goods_weight_total    NUMBER := 0;
        z_wagons_weight_total   NUMBER := 0;
        z_wagons_capaticy_total NUMBER := 0;
        z_lang                  VARCHAR2 (3) := get_kasutaja_keel (user);
        z_gng_check_count       NUMBER;
        z_gng_check             BOOLEAN;
        z_gng_check_error_level vjs.parameetrid.vxxrtus%TYPE;
        l_params                logger_service.logger.tab_param;
        l_step                  VARCHAR2 (300);
        l_number_regex          VARCHAR2 (50);
        l_danger_sign_clean     VARCHAR2 (300);
        l_danger_sign_validate  VARCHAR2 (300);
        l_package_amount_min    NUMBER;
        l_package_amount_max    NUMBER;
        l_package_amount_total  NUMBER;
    BEGIN
        FOR i IN 1 .. smgs.wagon.count
        LOOP
            l_step                  :=
                'FOR smgs.wagon '
                || i;

            IF smgs.wagon (i).capacity IS NULL
            THEN
                debug_message ('Wagon '
                               || smgs.wagon (i).wagon_nr
                               || ' has empty capacity '
                              ,'info');
                RETURN;
            END IF;

            z_wagons_weight_total   := z_wagons_weight_total + smgs.wagon (i).goods_weight;
            z_wagons_capaticy_total := z_wagons_capaticy_total + smgs.wagon (i).capacity;
        END LOOP;

        l_step              := 'getparamvalue SMGS_GNG_KOOD_VEATASE';

        BEGIN
            CASE lower (getparamvalue ('SMGS_GNG_KOOD_VEATASE'
                                      ,''))
                WHEN 'warning'
                THEN
                    z_gng_check_error_level := 'warning';
                WHEN 'error'
                THEN
                    z_gng_check_error_level := 'error';
                ELSE
                    z_gng_check_error_level := 'info';
            END CASE;
        END;

        /* Kontrollime tingimust, et Kauba GNG-kood K peab olema tabelis GNG_ANALYTIC_LIST_4025 */
        FOR i IN 1 .. smgs.goods.count
        LOOP
            l_step :=
                'FOR smgs.goods '
                || i;

            SELECT count (1)
              INTO z_gng_check_count
              FROM gng_analytic_list_4025
             WHERE kod = smgs.goods (i).gng;

            IF z_gng_check_count = 0
            THEN
                add_message (p_message        => vjs.vjs_tekstid$.get_tekst (p_kood     => 'GNG_CODE_CHECK_ERROR'
                                                                            ,p_kontekst => 'GNG_CODE_CHECK'
                                                                            ,p_keel     => z_lang
                                                                            ,p_par1     => smgs.goods (i).gng)
                            ,p_realm          => z_gng_check_error_level
                            ,p_code           => '-20000'
                            ,p_www_tekstid_id => NULL);
            END IF;
        END LOOP;

        /* Kauba GNG-kood K ei lange kokku parameetris SET_WARN_ON_GNG_CODES
        loetletud koodidega. Kui langeb, siis valjastada hoiatusteade "GNG-code <K> shouldnot be used."*/
        IF z_gng_check_error_level = 'WARNING'
        THEN
            FOR i IN 1 .. smgs.goods.count
            LOOP
                FOR k IN (SELECT column_value     AS gng_code
                            FROM TABLE (vjs.split_string (getparamvalue ('SET_WARN_ON_GNG_CODES'
                                                                        ,''))))
                LOOP
                    l_step      :=
                        'z_gng_check_error_level = WARNING and FOR smgs.goods '
                        || i
                        || ' and FOR gng_code '
                        || k.gng_code;
                    z_gng_check := TRUE;

                    IF smgs.goods (i).gng LIKE
                           k.gng_code
                           || '%'
                    THEN
                        z_gng_check := FALSE;
                    END IF;

                    IF NOT z_gng_check
                    THEN
                        add_message (p_message        => vjs.vjs_tekstid$.get_tekst (p_kood     => 'GNG_CODE_CHECK_WARN'
                                                                                    ,p_kontekst => 'GNG_CODE_CHECK'
                                                                                    ,p_keel     => z_lang
                                                                                    ,p_par1     => smgs.goods (i).gng)
                                    ,p_realm          => 'warning'
                                    ,p_code           => '-20000'
                                    ,p_www_tekstid_id => NULL);
                    END IF;
                END LOOP;
            END LOOP;
        END IF;

        /*Kauba GNG-kood K ei lange kokku parameetris SET_ERROR_ON_GNG_CODES
        loetletud koodidega. Kui langeb, siis valjastada veateade "GNG-code <K>is not allowed."*/

        IF z_gng_check_error_level = 'ERROR'
        THEN
            FOR i IN 1 .. smgs.goods.count
            LOOP
                FOR k IN ((SELECT column_value     AS gng_code
                             FROM TABLE (vjs.split_string (getparamvalue ('SET_ERROR_ON_GNG_CODES'
                                                                         ,'')))))
                LOOP
                    l_step      :=
                        'z_gng_check_error_level = ERROR and FOR smgs.goods '
                        || i
                        || ' and FOR gng_code '
                        || k.gng_code;
                    z_gng_check := TRUE;

                    IF smgs.goods (i).gng LIKE
                           k.gng_code
                           || '%'
                    THEN
                        z_gng_check := FALSE;
                    END IF;

                    IF NOT z_gng_check
                    THEN
                        add_message (p_message        => vjs.vjs_tekstid$.get_tekst (p_kood     => 'GNG_CODE_CHECK_ERROR'
                                                                                    ,p_kontekst => 'GNG_CODE_CHECK'
                                                                                    ,p_keel     => z_lang
                                                                                    ,p_par1     => smgs.goods (i).gng)
                                    ,p_realm          => 'error'
                                    ,p_code           => '-20000'
                                    ,p_www_tekstid_id => NULL);
                    END IF;
                END LOOP;
            END LOOP;
        END IF;

        FOR i IN 1 .. smgs.goods.count
        LOOP
            l_step               :=
                'FOR smgs.goods '
                || i
                || ' and z_goods_weight_total';
            z_goods_weight_total := z_goods_weight_total + smgs.goods (i).railway_weight;
        END LOOP;

        -- Clean up "ohtlikkuse tempel" (danger sign) BEFORE validation.
        -- Only numbers "0-9", a floating point "." and a pluss "+" sign allowed
        l_danger_sign_clean := '[^0-9\+\.]';

        FOR i IN 1 .. smgs.goods.count
        LOOP
            l_step :=
                'FOR smgs.goods '
                || i
                || ' and danger_sign clean'
                || smgs.goods (i).danger_sign;

            IF    smgs.goods (i).danger_sign IS NULL
               OR getparamvalue ('SMGS_GOODS_DANGER_SIGN_CHECK'
                                ,'E') = 'E'
            THEN
                NULL;
            ELSE
                smgs.goods (i).danger_sign :=
                    replace (smgs.goods (i).danger_sign
                            ,','
                            ,'.');
                smgs.goods (i).danger_sign :=
                    regexp_replace (smgs.goods (i).danger_sign
                                   ,l_danger_sign_clean
                                   ,'');
                smgs.goods (i).danger_sign := trim ('.' FROM trim ('+' FROM smgs.goods (i).danger_sign));
            END IF;
        END LOOP;

        -- Validate "ohtlikkuse tempel" (danger sign) against the format AFTER cleaning.
        -- Allowed is upto three whole numbers or floating point numbers separated by "+" sign
        l_number_regex      := '[0-9]+([.][0-9]*)?';
        l_danger_sign_validate :=
            '^'
            || l_number_regex
            || '(\+'
            || l_number_regex
            || ')?(\+'
            || l_number_regex
            || ')?$';

        FOR i IN 1 .. smgs.goods.count
        LOOP
            l_step :=
                'FOR smgs.goods '
                || i
                || ' and danger_sign validate'
                || smgs.goods (i).danger_sign;

            IF    smgs.goods (i).danger_sign IS NULL
               OR regexp_like (smgs.goods (i).danger_sign
                              ,l_danger_sign_validate)
               OR getparamvalue ('SMGS_GOODS_DANGER_SIGN_CHECK'
                                ,'E') = 'E'
            THEN
                NULL;
            ELSE
                add_message (p_message        => vjs.vjs_tekstid$.get_tekst (p_kood     => 'SMGS_GOODS_DANGER_SIGN_CHECK_ERROR'
                                                                            ,p_kontekst => 'SMGS_GOODS_DANGER_SIGN_CHECK'
                                                                            ,p_keel     => z_lang
                                                                            ,p_par1     => smgs.goods (i).danger_sign)
                            ,p_realm          => 'error'
                            ,p_code           => '-20000'
                            ,p_www_tekstid_id => NULL);
            END IF;
        END LOOP;

        /* Validate package amounts against the configured limits */
        l_package_amount_total := 0;
        FOR i IN 1 .. smgs.goods.count
        LOOP
            FOR j IN 1 .. smgs.goods (i).package.count
            LOOP
                l_step :=
                    'FOR smgs.goods '
                    || i
                    || ' and package '
                    || j;

                IF smgs.goods (i).package (j).code IS NOT NULL
                THEN
                    SELECT min_amount, max_amount
                    INTO l_package_amount_min, l_package_amount_max
                    FROM spv.package_type_limits
                    WHERE code = smgs.goods (i).package (j).code;
                END IF;

                IF smgs.goods (i).package (j).amount IS NOT NULL
                THEN
                    l_package_amount_total := l_package_amount_total + to_number(smgs.goods (i).package (j).amount);
                END IF;
                
                IF getparamvalue ('SMGS_GOODS_PACKAGE_LIMIT_CHECK'
                                 ,'E') = 'E'
                OR smgs.goods (i).package (j).code IS NULL
                OR smgs.goods (i).package (j).amount IS NULL
                OR (
                    (   l_package_amount_min IS NULL
                        OR ( 
                            l_package_amount_min IS NOT NULL 
                        AND to_number(smgs.goods (i).package (j).amount) >= l_package_amount_min
                        )
                    )
                    AND
                    (   l_package_amount_max IS NULL
                        OR  (
                            l_package_amount_max IS NOT NULL 
                        AND to_number(smgs.goods (i).package (j).amount) <= l_package_amount_max
                        AND to_number(smgs.goods (i).package (j).amount) <= to_number(getparamvalue('SMGS_GOODS_PACKAGE_TYPE_LIMIT', '99999'))
                        )
                    )
                )
                THEN
                    NULL;
                ELSE
                    add_message (p_message        => vjs.vjs_tekstid$.get_tekst (p_kood     => 'SMGS_GOODS_PACKAGE_LIMIT_CHECK_ERROR'
                                                                                ,p_kontekst => 'SMGS_GOODS_PACKAGE_LIMIT_CHECK'
                                                                                ,p_keel     => z_lang
                                                                                ,p_par1     => smgs.goods (i).package (j).amount)
                                ,p_realm          => 'error'
                                ,p_code           => '-20000'
                                ,p_www_tekstid_id => NULL);
                END IF;                
            END LOOP;
        END LOOP;

        IF getparamvalue ('SMGS_GOODS_PACKAGE_LIMIT_CHECK','E') = 'E'
        OR l_package_amount_total <= to_number(getparamvalue('SMGS_GOODS_PACKAGE_TOTAL_LIMIT', '99999'))
        THEN
            NULL;
        ELSE
            add_message (p_message        => vjs.vjs_tekstid$.get_tekst (p_kood     => 'SMGS_GOODS_PACKAGE_LIMIT_CHECK_ERROR'
                                                                        ,p_kontekst => 'SMGS_GOODS_PACKAGE_LIMIT_CHECK'
                                                                        ,p_keel     => z_lang
                                                                        ,p_par1     => l_package_amount_total)
                        ,p_realm          => 'error'
                        ,p_code           => '-20000'
                        ,p_www_tekstid_id => NULL);
        END IF;

        /* Kauba kogumass uletab vagunite kogu kandevoime */
        l_step              := 'Kauba kogumass uletab vagunite kogu kandevoime';

        IF z_goods_weight_total > (z_wagons_capaticy_total * 1000)
        THEN
            add_message (p_message        => get_tekst_in_lang (7006)
                        ,p_realm          => getparamvalue ('SMGS_KAUBA_KOGUMASS_VEATASE'
                                                           ,'warning')
                        ,p_code           => '-20000'
                        ,p_www_tekstid_id => 7006);
        END IF;

        /* Kauba kogumass uletab vagunite kogu kauba kaal */
        l_step              := 'Kauba kogumass uletab vagunite kogu kauba kaal';

        IF z_goods_weight_total > (z_wagons_capaticy_total * 1000)
        THEN
            add_message (p_message        => get_tekst_in_lang (7006)
                        ,p_realm          => getparamvalue ('SMGS_KAUBA_KOGUMASS_VEATASE'
                                                           ,'warning')
                        ,p_code           => '-20000'
                        ,p_www_tekstid_id => 7006);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.validate_goods'
                                            ,p_params => l_params);
    END validate_goods;

    PROCEDURE validate_wagons
    IS
        l_params     logger_service.logger.tab_param;
        l_step       VARCHAR2 (300);
        l_field_text VARCHAR2 (100);
    BEGIN
        FOR w_i IN 1 .. smgs.wagon.count
        LOOP
            l_step :=
                'FOR smgs.wagon '
                || w_i;
            /* correct null wagon data from DB   */
            correct_wagon_data (smgs.wagon (w_i)
                               ,smgs.smgs_number);
            l_step :=
                'FOR smgs.wagon '
                || w_i
                || ' and IF smgs.wagon (w_i).wagon_nr IS NULL';

            IF    smgs.wagon (w_i).wagon_nr IS NULL
               OR smgs.wagon (w_i).rw_admin IS NULL
               OR smgs.wagon (w_i).net_weight IS NULL
               OR smgs.wagon (w_i).capacity IS NULL
               OR smgs.wagon (w_i).axis IS NULL
               OR     smgs.wagon (w_i).goods_weight IS NULL
                  AND nvl (smgs.dokum_kood, 'x') <> 'ZPN' -- for IFTMIN
               OR smgs.wagon (w_i).provider IS NULL
               OR     nvl (smgs.dokum_kood, 'x') = 'ZPN' -- for IFTMIN_PN
                  AND (   smgs.wagon (w_i).owner_name IS NULL
                       OR smgs.wagon (w_i).notes IS NULL
                       OR smgs.wagon (w_i).kalibr_code IS NULL
                       OR smgs.wagon (w_i).prev_gng IS NULL
                       OR smgs.wagon (w_i).prev_etsng IS NULL)
            --OR smgs.wagon (w_i).kalibr_code IS NULL
            THEN
                l_field_text :=
                    CASE
                        WHEN smgs.wagon (w_i).wagon_nr IS NULL
                        THEN
                            ' (vaguninumber)'
                        WHEN smgs.wagon (w_i).rw_admin IS NULL
                        THEN
                            ' (rdt.admin)'
                        WHEN smgs.wagon (w_i).net_weight IS NULL
                        THEN
                            ' (taara)'
                        WHEN smgs.wagon (w_i).capacity IS NULL
                        THEN
                            ' (kandevoime)'
                        WHEN smgs.wagon (w_i).axis IS NULL
                        THEN
                            ' (teljede arv)'
                        WHEN     smgs.wagon (w_i).goods_weight IS NULL
                             AND nvl (smgs.dokum_kood, 'x') <> 'ZPN'
                        THEN
                            ' (kaubakaal)' -- for IFTMIN
                        WHEN smgs.wagon (w_i).provider IS NULL
                        THEN
                            ' (provider)'
                        WHEN     smgs.wagon (w_i).owner_name IS NULL
                             AND nvl (smgs.dokum_kood, 'x') = 'ZPN'
                        THEN
                            ' (owner_name)' -- for IFTMIN_PN
                        WHEN     smgs.wagon (w_i).notes IS NULL
                             AND nvl (smgs.dokum_kood, 'x') = 'ZPN'
                        THEN
                            ' (notes)' -- for IFTMIN_PN
                        WHEN     smgs.wagon (w_i).kalibr_code IS NULL
                             AND nvl (smgs.dokum_kood, 'x') = 'ZPN'
                        THEN
                            ' (kalibr_code)' -- for IFTMIN_PN
                        WHEN     smgs.wagon (w_i).prev_gng IS NULL
                             AND nvl (smgs.dokum_kood, 'x') = 'ZPN'
                        THEN
                            ' (prev_gng)' -- for IFTMIN_PN
                        WHEN     smgs.wagon (w_i).prev_etsng IS NULL
                             AND nvl (smgs.dokum_kood, 'x') = 'ZPN'
                        THEN
                            ' (prev_etsng)' -- for IFTMIN_PN
                        ELSE
                            ' (???)'
                    END;
                add_message (p_message        => replace (replace (get_tekst_in_lang (6516)
                                                                  ,'%1'
                                                                  ,smgs.wagon (w_i).wagon_nr)
                                                         ,'%2'
                                                         ,l_field_text)
                            ,p_realm          => 'error'
                            ,p_code           => '-20000'
                            ,p_replacement1   => smgs.wagon (w_i).wagon_nr
                            ,p_replacement2   => l_field_text
                            ,p_www_tekstid_id => 6516);
            END IF;

            l_step :=
                'FOR smgs.wagon '
                || w_i
                || ' and IF smgs.transportationstatus.is_reforwarding = 1';

            IF smgs.transportationstatus.is_reforwarding = 1
            THEN
                DECLARE
                    z_something_found edifact.vagun.vagun_nr%TYPE;
                BEGIN
                    IF smgs.transportationstatus.originalsmgs_edi_id IS NULL
                    THEN
                        smgs.transportationstatus.originalsmgs_edi_id := edifact.get_edi_id_by_smgs_number (smgs.transportationstatus.originalsmgsnumber);
                    END IF;

                    l_step :=
                        'FOR smgs.wagon '
                        || w_i
                        || ' and smgs.transportationstatus.is_reforwarding = 1 and INTO z_something_found';

                    SELECT vagun_nr
                      INTO z_something_found
                      FROM edifact.vagun
                     WHERE     sonum_id = smgs.transportationstatus.originalsmgs_edi_id
                           AND vagun_nr = smgs.wagon (w_i).wagon_nr;

                    debug_message ('Вагон '
                                   || smgs.wagon (w_i).wagon_nr
                                   || ' соответствует исходной накладной '
                                   || smgs.transportationstatus.originalsmgsnumber
                                   || '!'
                                  ,'info');
                EXCEPTION
                    WHEN no_data_found
                    THEN
                        debug_message ('Вагон '
                                       || smgs.wagon (w_i).wagon_nr
                                       || ' отсутствует в исходной накладной '
                                       || smgs.transportationstatus.originalsmgsnumber
                                       || '!'
                                      ,'error');
                    WHEN too_many_rows
                    THEN
                        debug_message ('Номер вагона '
                                       || smgs.wagon (w_i).wagon_nr
                                       || ' присутствует в исходной накладной '
                                       || smgs.transportationstatus.originalsmgsnumber
                                       || ' более чем в 1 экземпляре!'
                                      ,'error');
                    WHEN OTHERS
                    THEN
                        l_params := logger_service.logger.gc_empty_tab_param;
                        logger_service.logger.append_param (l_params
                                                           ,'l_step'
                                                           ,l_step);
                        logger_service.logger.log_error (p_text   => sqlerrm
                                                        ,p_scope  => 'spv.'
                                                                    || $$plsql_unit
                                                                    || '.validate_wagons - DECLARE z_something_found'
                                                        ,p_params => l_params);
                END;
            END IF;

            -- container
            FOR c_i IN 1 .. smgs.wagon (w_i).container.count
            LOOP
                l_step :=
                    'FOR smgs.wagon '
                    || w_i
                    || ' and FOR container '
                    || c_i;
                debug_message ('container_nr:'
                               || smgs.wagon (w_i).container (c_i).container_nr);
                debug_message ('net_weight:'
                               || smgs.wagon (w_i).container (c_i).net_weight);
                debug_message ('goods_weight:'
                               || smgs.wagon (w_i).container (c_i).goods_weight);
                debug_message ('ownership_form:'
                               || smgs.wagon (w_i).container (c_i).ownership_form);

                IF smgs.wagon (w_i).container (c_i).container_nr IS NULL
                THEN
                    add_message (p_message        => replace (get_tekst_in_lang (6517)
                                                             ,'%1'
                                                             ,smgs.wagon (w_i).container (c_i).container_nr)
                                ,p_realm          => 'error'
                                ,p_code           => '-20000'
                                ,p_www_tekstid_id => 6517
                                ,p_replacement1   => smgs.wagon (w_i).container (c_i).container_nr);
                ELSE
                    IF     smgs.wagon (w_i).container (c_i).net_weight IS NULL
                       AND NOT upper (smgs.data_source) = 'EDIFACT'
                    THEN
                        add_message (p_message        => replace (get_tekst_in_lang (6517)
                                                                 ,'%1'
                                                                 ,smgs.wagon (w_i).container (c_i).container_nr)
                                    ,p_realm          => 'warning'
                                    ,p_code           => '-20000'
                                    ,p_www_tekstid_id => 6606
                                    ,p_replacement1   => smgs.wagon (w_i).container (c_i).container_nr);
                    END IF;

                    IF     smgs.wagon (w_i).container (c_i).goods_weight IS NULL
                       AND NOT upper (smgs.data_source) = 'EDIFACT'
                    THEN
                        add_message (p_message        => replace (get_tekst_in_lang (6517)
                                                                 ,'%1'
                                                                 ,smgs.wagon (w_i).container (c_i).container_nr)
                                    ,p_realm          => 'warning'
                                    ,p_code           => '-20000'
                                    ,p_www_tekstid_id => 6607
                                    ,p_replacement1   => smgs.wagon (w_i).container (c_i).container_nr);
                    END IF;

                    IF     smgs.wagon (w_i).container (c_i).ownership_form IS NULL
                       AND NOT upper (smgs.data_source) = 'EDIFACT'
                    THEN
                        add_message (p_message        => replace (get_tekst_in_lang (6517)
                                                                 ,'%1'
                                                                 ,smgs.wagon (w_i).container (c_i).container_nr)
                                    ,p_realm          => 'warning'
                                    ,p_code           => '-20000'
                                    ,p_www_tekstid_id => 6608
                                    ,p_replacement1   => smgs.wagon (w_i).container (c_i).container_nr);
                    END IF;
                END IF;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            add_message (p_message        => get_tekst (6302)
                        ,p_realm          => 'error'
                        ,p_code           => '-20000'
                        ,p_www_tekstid_id => 6302);
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.validate_wagons'
                                            ,p_params => l_params);
    END validate_wagons;

    /* Added by ale_x @ 2016.09.22. Purpose: GS (payer/expeditor) information checking */

    FUNCTION get_participant_code (p_participant IN spv.smgs2_interface.t_edi_participant
                                  ,p_code_type   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_params logger_service.logger.tab_param;
    BEGIN
        FOR j IN 1 .. p_participant.codes.count
        LOOP
            IF p_participant.codes (j).code_type = p_code_type
            THEN
                RETURN p_participant.codes (j).code_value;
            END IF;
        END LOOP;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.get_participant_code'
                                            ,p_params => l_params);
            RETURN NULL;
    END get_participant_code;

    /* Added by ale_x @ 2018.12.22. Purpose: Participant codes addition (according to reverence books) */
    PROCEDURE set_participant_code (p_participant IN OUT smgs2_interface.t_edi_participant
                                   ,p_code_type   IN     VARCHAR2
                                   ,p_code_value  IN     VARCHAR2)
    IS
        z_found_and_set BOOLEAN := FALSE;
        l_params        logger_service.logger.tab_param;
    BEGIN
        FOR j IN 1 .. p_participant.codes.count
        LOOP
            IF p_participant.codes (j).code_type = p_code_type
            THEN
                p_participant.codes (j).code_value := p_code_value;
                z_found_and_set                    := TRUE;
            END IF;
        END LOOP;

        IF NOT z_found_and_set
        THEN
            p_participant.codes.extend;
            p_participant.codes (p_participant.codes.count).code_type  := p_code_type;
            p_participant.codes (p_participant.codes.count).code_value := p_code_value;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.set_participant_code'
                                            ,p_params => l_params);
    END set_participant_code;

    PROCEDURE validate_participants
    IS
        z_cn_count     PLS_INTEGER := 0;
        z_cz_count     PLS_INTEGER := 0;
        l_params       logger_service.logger.tab_param;
        l_step         VARCHAR2 (300);
        l_okpo_pattern VARCHAR2 (240);

        PROCEDURE validate_code_format
        IS
            z_message VARCHAR2 (1024)
                          := sass.get_tekst_in_lang (6637
                                                    ,NULL
                                                    ,v ('APP_USER'));

            -- Find out which pattern to validate OKPO code against
            FUNCTION get_okpo_rule_by_participant (p_participant IN smgs2_interface.t_edi_participant)
                RETURN VARCHAR2
            IS
                l_host_name VARCHAR2 (25 CHAR);
                z_out       VARCHAR2 (32767);
            BEGIN
                IF p_participant.state IS NOT NULL
                THEN
                    SELECT ra.rtadm_host_nimi
                      INTO l_host_name
                      FROM vjs.riigid                     r
                          ,vjs.raudteeadministratsioonid  ra
                     WHERE     r.lyhend = substr (p_participant.state
                                                 ,1
                                                 ,2)
                           AND ra.riik_riik_id = r.riik_id;
                END IF;

                IF l_host_name IS NOT NULL
                THEN
                    SELECT vaartus
                      INTO z_out
                      FROM edifact.sonumivahetuse_parameetrid
                     WHERE     parameeter = 'OKPO_CODE_FORMAT_MASK'
                           AND host = l_host_name;
                END IF;

                RETURN z_out;
            EXCEPTION
                WHEN no_data_found
                THEN
                    RETURN NULL;
            END;
        BEGIN
            FOR i IN 1 .. smgs.participant.count
            LOOP
                FOR j IN 1 .. smgs.participant (i).codes.count
                LOOP
                    l_step         :=
                        'FOR smgs.participant '
                        || i
                        || ' and FOR codes '
                        || j;

                    -- Validate code type Z01
                    IF     smgs.participant (i).codes (j).code_type = 'Z01'
                       AND length (smgs.participant (i).codes (j).code_value) <> 4
                    THEN
                        --For participant %1 role %2 code type of %3 is wrong format

                        add_message (p_message        => z_message
                                    ,p_realm          => 'error'
                                    ,p_code           => '-20000'
                                    ,p_www_tekstid_id => 6637
                                    ,p_replacement1   => smgs.participant (i).name
                                    ,p_replacement2   => smgs.participant (i).smgs_role
                                    ,p_replacement3   => smgs.participant (i).codes (j).code_type);
                    END IF;

                    -- Pattern no longer directly in the code but as a parameter table value
                    l_okpo_pattern := get_okpo_rule_by_participant (smgs.participant (i));

                    -- Pattern validation should only happen when the rule is found, otherwise it's ignored
                    IF l_okpo_pattern IS NOT NULL
                    THEN
                        /* Added by ALE_X @ 2017.01.31 */
                        IF     smgs.participant (i).codes (j).code_type = 'Z02'
                           AND NOT (regexp_like (smgs.participant (i).codes (j).code_value
                                                ,l_okpo_pattern))
                        THEN
                            --For participant code type of %3 is wrong format

                            add_message (p_message        => z_message
                                        ,p_realm          => 'error'
                                        ,p_code           => '-20000'
                                        ,p_www_tekstid_id => 6656
                                        ,p_replacement1   => smgs.participant (i).name
                                        ,p_replacement2   => smgs.participant (i).codes (j).code_type
                                        ,p_replacement3   => quote (smgs.participant (i).codes (j).code_value));
                        END IF;
                    END IF;

                    IF     smgs.participant (i).codes (j).code_type = 'Z03'
                       AND smgs.participant (i).smgs_role = 'GS'
                       AND NOT (regexp_like (smgs.participant (i).codes (j).code_value
                                            ,'^\d{10}$'))
                    THEN
                        --For participant code type of %3 is wrong format

                        add_message (p_message        => z_message
                                    ,p_realm          => 'error'
                                    ,p_code           => '-20000'
                                    ,p_www_tekstid_id => 6655
                                    ,p_replacement1   => smgs.participant (i).name
                                                        || ' / '
                                                        || smgs.participant (i).smgs_role
                                    ,p_replacement2   => smgs.participant (i).codes (j).code_type
                                    ,p_replacement3   => quote (smgs.participant (i).codes (j).code_value));
                    END IF;
                /* End of "Added by ALE_X @ 2017.01.31" */
                END LOOP;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.validate_participants - PROCEDURE validate_code_format'
                                                ,p_params => l_params);
        END validate_code_format;

        PROCEDURE check_mandatory_code (p_participant IN spv.smgs2_interface.t_edi_participant
                                       ,p_code_type   IN VARCHAR2)
        IS
            z_count   PLS_INTEGER := 0;
            z_message VARCHAR2 (1024)
                          := sass.get_tekst_in_lang (6532
                                                    ,NULL
                                                    ,v ('APP_USER'));
        BEGIN
            IF get_participant_code (p_participant
                                    ,p_code_type)
                   IS NOT NULL
            THEN
                RETURN;
            END IF;

            z_message :=
                replace (z_message
                        ,'%1'
                        ,p_participant.name);
            z_message :=
                replace (z_message
                        ,'%2'
                        ,p_participant.smgs_role);
            z_message :=
                replace (z_message
                        ,'%3'
                        ,p_code_type);
            add_message (p_message        => z_message
                        ,p_realm          => 'error'
                        ,p_code           => '-20000'
                        ,p_www_tekstid_id => 6532
                        ,p_replacement1   => p_participant.name
                        ,p_replacement2   => p_participant.smgs_role
                        ,p_replacement3   => p_code_type);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.validate_participants - PROCEDURE check_mandatory_code'
                                                ,p_params => l_params);
        END check_mandatory_code;

        /* Added by Ale_x @ 2016.09.22. Purpose: GS (payer/expeditor) information checking */
        PROCEDURE validate_payers_data
        IS
            z_gs_count PLS_INTEGER := 0;
        BEGIN
            FOR i IN 1 .. smgs.participant.count
            LOOP
                l_step :=
                    'FOR smgs.participant '
                    || i;

                IF smgs.participant (i).smgs_role = 'GS'
                THEN
                    z_gs_count := z_gs_count + 1;

                    IF smgs.participant (i).state = 'RU'
                    THEN
                        /* check for Z03 ("ELS") code type for PAYER / EXPEDITOR */
                        check_mandatory_code (smgs.participant (i)
                                             ,'Z03');

                        /* Added by ALE_X @ 01.11.2018                                        */
                        /* In accordance with the requirements of EVR-RZD protocol 05.07.2018 */
                        /* Payer "Грузополучатель (РЖД)" is prohibited!                       */
                        l_step :=
                            'FOR smgs.participant '
                            || i
                            || ' and IF LOWER (smgs.participant (i).name) LIKE';

                        IF    lower (smgs.participant (i).name) LIKE '%грузополучатель (ржд)%'
                           OR lower (smgs.participant (i).name) LIKE '%грузополучатель%'
                        THEN
                            add_message (sass.get_tekst_in_lang (6737
                                                                ,NULL
                                                                ,v ('APP_USER'))
                                        ,'error');
                        END IF;
                    /* End of "Added by ALE_X @ 01.11.2018"                                */

                    END IF;

                    /* Checking if Undertaker (CA) exists with taken undertakerCode (in field parent_participant_code) */
                    FOR j IN 1 .. smgs.participant.count
                    LOOP
                        l_step :=
                            'FOR smgs.participant '
                            || i
                            || ' and Checking if Undertaker (CA) exists FOR smgs.participant '
                            || j;

                        IF     smgs.participant (j).smgs_role = 'CA'
                           AND get_participant_code (smgs.participant (j)
                                                    ,p_code_type => 'Z13') = smgs.participant (i).parent_participant_code
                        THEN
                            IF nvl (v ('APP_USER'), user) = 'DENISS_LABUNETS'
                            THEN
                                sass.debug.writeln ($$plsql_unit
                                                   ,smgs.participant (i).name
                                                    || ' Change parent_id '
                                                    || smgs.participant (i).parent_participant_id
                                                    || ' to '
                                                    || smgs.participant (j).participant_id);
                            ELSE
                                smgs.participant (i).parent_participant_id := smgs.participant (j).participant_id;
                            END IF;

                            EXIT;
                        END IF;
                    END LOOP;

                    l_step     :=
                        'FOR smgs.participant '
                        || i
                        || ' and IF smgs.participant (i).parent_participant_id IS NULL';

                    IF smgs.participant (i).parent_participant_id IS NULL
                    THEN
                        add_message (p_message        => replace (sass.get_tekst_in_lang (6583
                                                                                         ,NULL
                                                                                         ,v ('APP_USER'))
                                                                 ,'%1'
                                                                 ,smgs.participant (i).name)
                                    ,p_realm          => 'warning'
                                    ,p_www_tekstid_id => 6583
                                    ,p_replacement1   => smgs.participant (i).name);
                    END IF;
                END IF;
            END LOOP;

            l_step := 'IF z_gs_count < 1';

            IF     z_gs_count < 1
               AND nvl (smgs.dokum_kood, 'x') <> 'ZPN' -- exclusion for IFTMIN_PN
            THEN
                add_message (p_message        => sass.get_tekst_in_lang (6582
                                                                        ,NULL
                                                                        ,v ('APP_USER'))
                            ,p_realm          => 'error'
                            ,p_www_tekstid_id => 6582);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.validate_participants - PROCEDURE validate_payers_data'
                                                ,p_params => l_params);
        END validate_payers_data;

        /* End of "Added by Ale_x @ 2016.09.22". */
        /* Added by Ale_x @ 2016.09.23. Purpose: CA (undertaker) information checking */
        PROCEDURE validate_undertakers_data
        IS
            z_ca_count             PLS_INTEGER := 0;
            z_undertaker_rics_code vedajad_rics.kood%TYPE;
            z_payer_found          BOOLEAN := FALSE;
        BEGIN
            FOR i IN 1 .. smgs.participant.count
            LOOP
                l_step :=
                    'FOR smgs.participant '
                    || i;

                IF smgs.participant (i).smgs_role = 'CA'
                THEN
                    z_ca_count := z_ca_count + 1;

                    /* check for Z13 code type */
                    check_mandatory_code (smgs.participant (i)
                                         ,'Z13');
                    z_undertaker_rics_code :=
                        get_participant_code (smgs.participant (i)
                                             ,'Z13');

                    IF smgs.participant (i).state IS NULL
                    THEN
                        smgs.participant (i).state := get_undertaker_state (z_undertaker_rics_code);
                    END IF;

                    /* Checking if RZD-undertaker has at least one PAYER */
                    IF     (   get_participant_code (smgs.participant (i)
                                                    ,'Z13') = '0020'
                            OR smgs.participant (i).state = 'RU')
                       AND nvl (smgs.dokum_kood, 'x') <> 'ZPN' -- exclusion for IFTMIN_PN
                    THEN
                        z_payer_found := FALSE;

                        FOR j IN 1 .. smgs.participant.count
                        LOOP
                            l_step :=
                                'FOR smgs.participant '
                                || i
                                || ' and IF smgs.participant (j).smgs_role = GS - FOR smgs.participant '
                                || i;

                            IF     smgs.participant (j).smgs_role = 'GS' /* Changed by Elecalarms. GS association should be by "participant_id" */
                               AND smgs.participant (j).parent_participant_id = smgs.participant (i).participant_id
                            /* End of "Changed by Elecalarms" */
                            THEN
                                z_payer_found := TRUE;
                                debug_message (concat ('Payer for undertaker '
                                                      ,smgs.participant (i).name)
                                               || concat (' ('
                                                         ,smgs.participant (i).state
                                                          || ')')
                                               || concat (' has found: '
                                                         ,smgs.participant (j).name));
                                EXIT;
                            END IF;
                        END LOOP;

                        l_step        :=
                            'FOR smgs.participant '
                            || i
                            || ' and IF NOT z_payer_found';

                        IF NOT z_payer_found
                        THEN
                            add_message (p_message        => replace (sass.get_tekst_in_lang (6586
                                                                                             ,NULL
                                                                                             ,v ('APP_USER'))
                                                                     ,'%1'
                                                                     ,smgs.participant (i).name)
                                        ,p_realm          => 'error'
                                        ,p_www_tekstid_id => 6586
                                        ,p_replacement1   => smgs.participant (i).name);
                        END IF;
                    END IF;

                    /* Added by ALE_X @ 24.12.2018. */
                    /* Purpose: check estonian UNDERTAKER conformity to RECIPIENT and DESTINATION STATION */
                    IF     smgs.participant (i).state = 'EE'
                       AND smgs.stationdestination.state = 'EE'
                       AND smgs.stationdeparture.state != 'EE'
                    THEN
                        l_step :=
                            'FOR smgs.participant '
                            || i
                            || ' and get_kliendi_oodatav_vedaja';

                        DECLARE
                            z_expect_undertaker_rics_code VARCHAR2 (32);
                            z_entrust_to_change_waybills  VARCHAR2 (1);
                            z_power_of_attorney           VARCHAR2 (1000);
                            z_temp_smgs_status            VARCHAR2 (32);
                            z_eesti_vedaja_kood4          vjs.vedajad_rics.evr_klient_kood4%TYPE;
                            z_message_txt                 VARCHAR2 (2048);
                            z_message                     spv.smgs2_validate.tb_validation_message;
                        BEGIN
                            get_kliendi_oodatav_vedaja (p_klient_kood4                => smgs.recipient_code
                                                       ,p_jaam_kood6                  => smgs.stationdestination.code6
                                                       ,p_aeg                         => nvl (smgs.created_at, sysdate)
                                                       ,p_oodatav_vedaja_rics_kood    => z_expect_undertaker_rics_code
                                                       ,p_saatelehte_muutmise_volitus => z_entrust_to_change_waybills
                                                       ,p_volituse_andmed             => z_power_of_attorney);

                            l_step :=
                                'FOR smgs.participant '
                                || i
                                || ' and IF z_undertaker_rics_code != z_expect_undertaker_rics_code';

                            IF z_undertaker_rics_code != z_expect_undertaker_rics_code
                            THEN
                                IF upper (z_entrust_to_change_waybills) IN ('J'
                                                                           ,'Y')
                                THEN
                                    dbms_output.put_line ('Incorrect carrier in Estonia: '
                                                          || smgs.participant (i).code4);
                                    smgs.participant (i).code4     := z_expect_undertaker_rics_code;
                                    set_participant_code (smgs.participant (i)
                                                         ,'Z13'
                                                         ,z_expect_undertaker_rics_code);

                                    l_step                         :=
                                        'FOR smgs.participant '
                                        || i
                                        || ' and INTO smgs.participant (i).name, z_eesti_vedaja_kood4';

                                    SELECT nimi, evr_klient_kood4
                                      INTO smgs.participant (i).name, z_eesti_vedaja_kood4
                                      FROM vjs.vedajad_rics
                                     WHERE kood = z_expect_undertaker_rics_code;

                                    l_step                         :=
                                        'FOR smgs.participant '
                                        || i
                                        || ' and set_participant_code Z01';
                                    set_participant_code (smgs.participant (i)
                                                         ,'Z01'
                                                         ,z_eesti_vedaja_kood4);
                                    smgs.participant (i).reg_code  := '';
                                    l_step                         :=
                                        'FOR smgs.participant '
                                        || i
                                        || ' and set_participant_code Z00';
                                    set_participant_code (smgs.participant (i)
                                                         ,'Z00'
                                                         ,'');
                                    smgs.participant (i).agent     := '';
                                    smgs.participant (i).city      := '';
                                    smgs.participant (i).street    := '';
                                    smgs.participant (i).zipcode   := '';
                                    smgs.participant (i).telefon   := '';
                                    smgs.participant (i).fax       := '';
                                    smgs.participant (i).email     := '';
                                    smgs.participant (i).signature := '';

                                    z_temp_smgs_status             := smgs.status;
                                    smgs.status                    := 'SK_VALIDATOR';
                                    l_step                         :=
                                        'FOR smgs.participant '
                                        || i
                                        || ' and spv.smgs2_validate.save_document';
                                    spv.smgs2_validate.save_document (smgs
                                                                     ,z_message);
                                    l_step                         :=
                                        'FOR smgs.participant '
                                        || i
                                        || ' and instead of vjs.log_debug';
                                    l_params                       := logger_service.logger.gc_empty_tab_param;
                                    logger_service.logger.append_param (l_params
                                                                       ,'l_step'
                                                                       ,l_step);
                                    logger_service.logger.append_param (l_params
                                                                       ,'Changed smgs-waybill data'
                                                                       ,smgs.smgs_number);
                                    logger_service.logger.append_param (l_params
                                                                       ,'Recipient => '
                                                                       ,smgs.recipient_code);
                                    logger_service.logger.append_param (l_params
                                                                       ,'Destination station => '
                                                                       ,smgs.stationdestination.code6);
                                    logger_service.logger.append_param (l_params
                                                                       ,'Undertaker (carrier) has been changed: '
                                                                       ,z_undertaker_rics_code);
                                    logger_service.logger.append_param (l_params
                                                                       ,'Undertaker (carrier) has been changed -> '
                                                                       ,z_expect_undertaker_rics_code);
                                    logger_service.logger.append_param (l_params
                                                                       ,'Power of attorney was: '
                                                                       ,z_power_of_attorney);
                                    logger_service.logger
                                      .log_error (p_text   => sqlerrm
                                                 ,p_scope  => 'spv.'
                                                             || $$plsql_unit
                                                             || '.validate_participants - PROCEDURE validate_undertakers_data - Incorrect carrier in Estonia'
                                                 ,p_params => l_params);
                                    add_message (p_message        => NULL
                                                ,p_realm          => 'warning'
                                                ,p_www_tekstid_id => 6739
                                                ,p_replacement1   => smgs.recipient_nimi
                                                                    || ' / '
                                                                    || smgs.recipient_code
                                                ,p_replacement2   => smgs.stationdestination.name
                                                                    || ' / '
                                                                    || smgs.stationdestination.code6
                                                ,p_replacement3   => z_expect_undertaker_rics_code
                                                ,p_replacement4   => z_undertaker_rics_code
                                                ,p_replacement5   => smgs.edi_id);
                                    smgs.status                    := z_temp_smgs_status;
                                    z_message_txt                  :=
                                        get_tekst (6739
                                                  ,'EST')
                                        || ' <br>'
                                        || www.crlf
                                        || get_tekst (6739
                                                     ,'RUS');

                                    z_undertaker_rics_code         := z_expect_undertaker_rics_code;
                                ELSE
                                    add_message (p_message        => NULL
                                                ,p_realm          => 'warning'
                                                ,p_www_tekstid_id => 6738
                                                ,p_replacement1   => smgs.recipient_nimi
                                                                    || ' / '
                                                                    || smgs.recipient_code
                                                ,p_replacement2   => smgs.stationdestination.name
                                                                    || ' / '
                                                                    || smgs.stationdestination.code6
                                                ,p_replacement3   => z_expect_undertaker_rics_code
                                                ,p_replacement4   => z_undertaker_rics_code
                                                ,p_replacement5   => smgs.edi_id);

                                    z_message_txt :=
                                        get_tekst (6738
                                                  ,'EST')
                                        || ' <br>'
                                        || www.crlf
                                        || get_tekst (6738
                                                     ,'RUS');
                                END IF;

                                z_message_txt :=
                                    substitute (z_message_txt
                                               ,smgs.recipient_nimi
                                                || ' / '
                                                || smgs.recipient_code
                                               ,smgs.stationdestination.name
                                                || ' / '
                                                || smgs.stationdestination.code6
                                               ,z_expect_undertaker_rics_code
                                               ,z_undertaker_rics_code
                                               ,smgs.edi_id);

                                debug.send_email (to_name      => getparamvalue ('SMGS_VALIDATE.VALE_VEDAJA'
                                                                                ,'alex@evr.ee')
                                                 ,from_name    => 'vjs@evr.ee'
                                                 ,taskname     => 'Incoming SMGS-waybill nr.'
                                                                 || smgs.smgs_number
                                                                 || ' validation'
                                                 ,str          => z_message_txt
                                                 ,content_type => 'text/html');
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_params := logger_service.logger.gc_empty_tab_param;
                                logger_service.logger.append_param (l_params
                                                                   ,'l_step'
                                                                   ,l_step);
                                logger_service.logger
                                  .log_error (p_text   => sqlerrm
                                             ,p_scope  => 'spv.'
                                                         || $$plsql_unit
                                                         || '.validate_participants - PROCEDURE validate_payers_data - get_kliendi_oodatav_vedaja'
                                             ,p_params => l_params);
                        END;
                    END IF;
                END IF;
            END LOOP;

            /* End of "Added by ALE_X @ 24.12.2018" */

            /* Checking that at least 1 undertaker found. */
            l_step := 'Checking that at least 1 undertaker found.';

            IF z_ca_count < 1
            THEN
                add_message (p_message        => sass.get_tekst_in_lang (6514
                                                                        ,NULL
                                                                        ,v ('APP_USER'))
                            ,p_realm          => 'error'
                            ,p_www_tekstid_id => 6514);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.validate_participants - PROCEDURE validate_payers_data'
                                                ,p_params => l_params);
        END validate_undertakers_data;
    BEGIN
        FOR i IN 1 .. smgs.participant.count
        LOOP
            l_step :=
                'FOR smgs.participant '
                || i;

            IF smgs.participant (i).smgs_role = 'CN'
            THEN
                z_cn_count := z_cn_count + 1;
            END IF;

            IF smgs.participant (i).smgs_role = 'CZ'
            THEN
                z_cz_count := z_cz_count + 1;

                IF smgs.participant (i).state = 'RU'
                THEN
                    /* check for Z03 code type for */
                    check_mandatory_code (smgs.participant (i)
                                         ,'Z03');
                END IF;

                IF smgs.participant (i).state = 'EE'
                THEN
                    /* check CARRIER for RECEIVER in Estonia */
                    NULL;
                END IF;
            END IF;
        END LOOP;

        l_step := 'IF z_cn_count < 1';

        IF z_cn_count < 1
        THEN
            add_message (p_message        => sass.get_tekst_in_lang (6144
                                                                    ,NULL
                                                                    ,v ('APP_USER'))
                        ,p_realm          => 'error'
                        ,p_www_tekstid_id => 6144);
        END IF;

        l_step := 'IF z_cz_count < 1';

        IF z_cz_count < 1
        THEN
            add_message (p_message        => sass.get_tekst_in_lang (6145
                                                                    ,NULL
                                                                    ,v ('APP_USER'))
                        ,p_realm          => 'error'
                        ,p_www_tekstid_id => 6145);
        END IF;

        validate_undertakers_data;

        validate_payers_data;

        validate_code_format;
    EXCEPTION
        WHEN OTHERS
        THEN
            add_message (p_message        => get_tekst (6302)
                        ,p_realm          => 'error'
                        ,p_code           => '-20000'
                        ,p_www_tekstid_id => 6302);
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.validate_participants'
                                            ,p_params => l_params);
    END validate_participants;

    PROCEDURE validate_tempels
    IS
        l_params logger_service.logger.tab_param;
    BEGIN
        --Stub procedure for stamps (tempels) validation, currently no checks necessary
        NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.validate_tempels'
                                            ,p_params => l_params);
    END validate_tempels;

    PROCEDURE validate_leads
    IS
        lpreviouslead spv.smgs2_interface.t_edi_lead;
        null_record   spv.smgs2_interface.t_edi_lead;
    BEGIN
        IF getparamvalue ('SAATELEHTE_PLOMMI_NR_PARANDUS'
                         ,'E') = 'J'
        THEN
            null_record.lead_nr := NULL;
            null_record.owner   := NULL;
            null_record.amount  := NULL;
            null_record.station := NULL;

            --Procedure for leads/seals/locking devices ("plommid") validation
            /* wagons */
            FOR i IN 1 .. smgs.wagon.count
            LOOP
                lpreviouslead := null_record;

                FOR j IN 1 .. smgs.wagon (i).lead.count -- Leads/seals placed on the wagon
                LOOP
                    -- Attributes avalilable to check are:
                    -- smgs.wagon (i).LEAD (j).lead_nr
                    -- smgs.wagon (i).LEAD (j).amount
                    -- REPLACE (smgs.wagon (i).LEAD (j).owner, 'SH', 'CZ')               -- SH and CZ = "sender"
                    -- smgs.wagon (i).LEAD (j).station
                    IF trim (smgs.wagon (i).lead (j).lead_nr) IS NULL
                    THEN
                        IF lpreviouslead.lead_nr IS NULL
                        THEN
                            FOR k IN 1 .. smgs.wagon (i).lead.count -- Looking for first "not null" seal sign
                            LOOP
                                IF     trim (smgs.wagon (i).lead (k).lead_nr) IS NOT NULL
                                   AND smgs.wagon (i).lead (k).owner = smgs.wagon (i).lead (j).owner
                                THEN
                                    lpreviouslead := smgs.wagon (i).lead (k);
                                    EXIT;
                                END IF;
                            END LOOP;
                        END IF;

                        IF lpreviouslead.lead_nr IS NOT NULL
                        THEN
                            smgs.wagon (i).lead (j).lead_nr := lpreviouslead.lead_nr;
                        END IF;
                    END IF;

                    lpreviouslead := smgs.wagon (i).lead (j);
                    NULL;
                -- lead
                END LOOP j;

                /* container on the wagon */
                FOR j IN 1 .. smgs.wagon (i).container.count
                LOOP
                    lpreviouslead := null_record;

                    FOR k IN 1 .. smgs.wagon (i).container (j).lead.count -- Leads/seals placed on the container
                    LOOP
                        NULL;

                        -- Attributes avalilable to check are:
                        -- smgs.wagon (i).container (j).LEAD (k).lead_nr
                        -- NVL (smgs.wagon (i).container (j).LEAD (k).amount, 1)
                        -- smgs.wagon (i).container (j).LEAD (k).owner
                        -- smgs.wagon (i).container (j).LEAD (k).station
                        IF trim (smgs.wagon (i).container (j).lead (k).lead_nr) IS NULL
                        THEN
                            IF lpreviouslead.lead_nr IS NULL
                            THEN
                                FOR l IN 1 .. smgs.wagon (i).container (j).lead.count -- Looking for first "not null" seal sign
                                LOOP
                                    IF     trim (smgs.wagon (i).container (j).lead (l).lead_nr) IS NOT NULL
                                       AND smgs.wagon (i).container (j).lead (k).owner = smgs.wagon (i).container (j).lead (l).owner
                                    THEN
                                        lpreviouslead := smgs.wagon (i).container (j).lead (l);
                                        EXIT;
                                    END IF;
                                END LOOP;
                            END IF;

                            IF lpreviouslead.lead_nr IS NOT NULL
                            THEN
                                smgs.wagon (i).container (j).lead (k).lead_nr := lpreviouslead.lead_nr;
                            END IF;
                        END IF;

                        lpreviouslead := smgs.wagon (i).container (j).lead (k);
                    END LOOP k;
                END LOOP j;
            END LOOP i;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            add_message (p_message        => get_tekst (6302)
                        ,p_realm          => 'error'
                        ,p_code           => sqlcode
                        ,p_www_tekstid_id => 6302);
            debug.writeln ($$plsql_unit
                          ,dbms_utility.format_error_stack
                           || ', '
                           || dbms_utility.format_error_backtrace);
    END validate_leads;

    PROCEDURE validate_document (p_document IN OUT smgs2_interface.t_smgs
                                ,p_message  IN OUT tb_validation_message)
    IS
        z_count  INTEGER;
        l_params logger_service.logger.tab_param;
        l_step   VARCHAR2 (100);
    BEGIN
        -- TODO kui ZPN siis ... ?

        l_step     := 'begin';
        smgs       := p_document;

        -- empty error collection
        message.delete;

        IF smgs.smgs_number IS NULL
        THEN
            add_message (p_message        => sass.get_tekst_in_lang (6140
                                                                    ,NULL
                                                                    ,v ('APP_USER'))
                        ,p_realm          => 'error'
                        ,p_www_tekstid_id => 6140);
        END IF;

        /* unique SMGS number */
        l_step     := 'unique SMGS number';

        IF v ('MODE') = 'CREATE'
        THEN
            SELECT count (0)
              INTO z_count
              FROM spv.edifact_sonum s
             WHERE     s.saadetise_nr = smgs.smgs_number
                   AND nvl (trunc (s.sn_kuupaev), trunc (s.loomise_kuupaev)) > sysdate - 365;

            IF z_count > 0
            THEN
                add_message (p_message        => sass.get_tekst_in_lang (6295
                                                                        ,NULL
                                                                        ,v ('APP_USER'))
                            ,p_realm          => 'error'
                            ,p_www_tekstid_id => 6295);
            END IF;
        END IF;

        /* Mode EDIT. Original SMGS number must be saved first */
        l_step     := 'Mode EDIT. Original SMGS number must be saved first';

        IF v ('MODE') = 'EDIT'
        THEN
            SELECT count (0)
              INTO z_count
              FROM spv.edifact_sonum s
             WHERE     s.saadetise_nr = smgs.smgs_number
                   AND s.saad_funk_kood IN (9
                                           ,4)
                   AND nvl (trunc (s.sn_kuupaev), trunc (s.loomise_kuupaev)) > sysdate - 365;

            IF z_count = 0
            THEN
                add_message (p_message        => sass.get_tekst_in_lang (6363
                                                                        ,NULL
                                                                        ,v ('APP_USER'))
                            ,p_realm          => 'error'
                            ,p_www_tekstid_id => 6363);
            END IF;
        END IF;

        l_step     := 'IF smgs.smgs_type IS NULL';

        IF smgs.smgs_type IS NULL
        THEN
            add_message (p_message        => sass.get_tekst_in_lang (6141
                                                                    ,NULL
                                                                    ,v ('APP_USER'))
                        ,p_realm          => 'error'
                        ,p_www_tekstid_id => 6141);
        END IF;

        l_step     := 'IF smgs.goods.COUNT = 0';

        IF     smgs.goods.count = 0
           AND nvl (smgs.dokum_kood, 'x') <> 'ZPN' -- exclusion for IFTMIN_PN
        THEN
            add_message (p_message        => sass.get_tekst_in_lang (6142
                                                                    ,NULL
                                                                    ,v ('APP_USER'))
                        ,p_realm          => 'error'
                        ,p_www_tekstid_id => 6142);
        END IF;

        l_step     := 'IF smgs.wagon.COUNT = 0';

        IF smgs.wagon.count = 0
        THEN
            add_message (p_message        => sass.get_tekst_in_lang (6143
                                                                    ,NULL
                                                                    ,v ('APP_USER'))
                        ,p_realm          => 'error'
                        ,p_www_tekstid_id => 6143);
        END IF;

        l_step     := 'validate';
        validate_texts;
        validate_stations;
        validate_participants;
        validate_goods;
        validate_wagons;
        validate_references;
        validate_tempels;
        validate_leads;
        p_message  := message;
        p_document := smgs;
    EXCEPTION
        WHEN OTHERS
        THEN
            add_message (p_message        => get_tekst (6302)
                        ,p_realm          => 'error'
                        ,p_code           => sqlcode
                        ,p_www_tekstid_id => 6302);
            l_params  := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.validate_document'
                                            ,p_params => l_params);
            p_message := message;
    END validate_document;

    FUNCTION get_messages (p_message IN tb_validation_message)
        RETURN VARCHAR2
    IS
        z_out    VARCHAR2 (32767);
        l_params logger_service.logger.tab_param;
    BEGIN
        FOR i IN 1 .. p_message.count
        LOOP
            IF p_message (i).realm = 'error'
            THEN
                z_out :=
                    z_out
                    || '<p style="color:red;">'
                    || p_message (i).message
                    || '</p>';
            ELSIF p_message (i).realm = 'warning'
            THEN
                z_out :=
                    z_out
                    || '<p style="color:blue;">'
                    || p_message (i).message
                    || '</p>';
            ELSE
                z_out :=
                    z_out
                    || '<p style="color:green;">'
                    || p_message (i).message
                    || '</p>';
            END IF;

            IF i > 5
            THEN
                z_out :=
                    z_out
                    || '...';
                EXIT;
            END IF;
        END LOOP;

        RETURN z_out;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.get_messages'
                                            ,p_params => l_params);
    END get_messages;

    PROCEDURE set_document_status (p_edi_id IN VARCHAR2
                                  ,p_status IN VARCHAR2 DEFAULT 'EDITED')
    IS
        z_count  INTEGER;
        l_params logger_service.logger.tab_param;
    BEGIN
        IF p_status = 'EDITED'
        THEN
            /*set status to 5- asendus*/
            UPDATE edifact.sonum
               SET saad_funk_kood = '4'
             WHERE id = p_edi_id;

            z_count  := SQL%ROWCOUNT;
            COMMIT;

            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'task_id'
                                               ,'set_document_status');

            IF z_count > 0
            THEN
                logger_service.logger.log_info (p_text   => 'Documents ID='
                                                           || p_edi_id
                                                           || ' updated.'
                                               ,p_scope  => 'spv.'
                                                           || $$plsql_unit
                                                           || '.set_document_status - z_count > 0'
                                               ,p_params => l_params);
            ELSE
                logger_service.logger.log_info (p_text   => 'No Documents ID='
                                                           || p_edi_id
                                                           || ' is found for update.'
                                               ,p_scope  => 'spv.'
                                                           || $$plsql_unit
                                                           || '.set_document_status - z_count = 0'
                                               ,p_params => l_params);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.set_document_status'
                                            ,p_params => l_params);
    END set_document_status;

    FUNCTION define_mode (p_document IN smgs2_interface.t_smgs)
        RETURN VARCHAR2
    IS
        p_saad_funk_kood VARCHAR2 (1) := '9';
        z_count          INTEGER := 0;
        l_params         logger_service.logger.tab_param;
    BEGIN
        /* if edit mode then new record status is 4(parandus) and old record have a nonchanged status */
        IF     p_document.edi_id IS NOT NULL
           AND p_document.status = 'PORTAL'
        THEN
            p_saad_funk_kood := 4;
        ELSIF     p_document.edi_id IS NULL
              AND p_document.status = 'PORTAL'
        THEN
            p_saad_funk_kood := 9;
        ELSE
            /* if document with current number is just exist, then status=4 else status=9 */

            SELECT count (0)
              INTO z_count
              FROM spv.edifact_sonum s
             WHERE     s.saadetise_nr = p_document.smgs_number
                   AND s.loomise_kuupaev > sysdate - 20;

            IF z_count > 0
            THEN
                /*4-parandus*/
                p_saad_funk_kood := '4';
            ELSE
                /*9-original*/
                p_saad_funk_kood := '9';
            END IF;
        END IF;

        RETURN p_saad_funk_kood;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.define_mode'
                                            ,p_params => l_params);
    END define_mode;

    FUNCTION get_riik_code (p_station_code6 IN VARCHAR2)
        RETURN VARCHAR2
    IS
        z_riik_code VARCHAR2 (2);
        l_params    logger_service.logger.tab_param;
    BEGIN
        SELECT max (lyhend) KEEP (DENSE_RANK FIRST ORDER BY rate)     AS lyhend
          INTO z_riik_code
          FROM (SELECT rg.lyhend, '1' AS rate
                  FROM jaamad                     j
                      ,riigid                     rg
                      ,raudteeadministratsioonid  ra
                      ,raudteed                   rt
                 WHERE     j.raudtee_kood = rt.kood
                       AND rt.raudtadm_kood = ra.kood
                       AND rg.riik_id = ra.riik_riik_id
                       AND j.kood6 = p_station_code6
                UNION
                -- Славков Полудиновы ЛХС Poola 074286
                SELECT 'PL' AS lyhend, '3' AS rate
                  FROM dual
                 WHERE p_station_code6 = '074286'
                UNION
                SELECT strana.mnemokod2 AS lyhend, '2' AS rate
                  FROM ibmu.st_3str
                      ,ibmu.adm
                      ,ibmu.strana
                 WHERE     p_station_code6 = trim (lpad (st_3str.kod
                                                        ,6
                                                        ,'0'))
                       AND adm.adm_id = st_3str.adm_id
                       AND strana.kod_iso = adm.kod_iso);

        RETURN z_riik_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_station_code6 IN'
                                               ,p_station_code6);
            logger_service.logger.append_param (l_params
                                               ,'RETURN z_riik_code'
                                               ,z_riik_code);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.get_riik_code'
                                            ,p_params => l_params);
            RETURN NULL;
    END get_riik_code;

    FUNCTION get_entry_station_code (p_exit_station_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        z_out    VARCHAR2 (8);
        l_params logger_service.logger.tab_param;
    BEGIN
        IF p_exit_station_code IS NULL
        THEN
            RETURN NULL;
        END IF;

        SELECT txt
          INTO z_out
          FROM (SELECT txt
                  FROM (SELECT CASE
                                   WHEN sp.stan2_ex_id = 0
                                   THEN
                                       at1.kod
                                       || st1.kod
                                   ELSE
                                       a2.kod
                                       || s2.kod
                               END    txt
                          FROM ibmu.stan        s1
                              ,ibmu.stik_punkt  sp
                               LEFT JOIN ibmu.stan1 st1 ON sp.stan2_os_id = st1.stan_id
                               LEFT JOIN ibmu.adm at1 ON st1.adm_id = at1.adm_id
                               LEFT JOIN ibmu.stan s2 ON s2.stan_id = sp.stan2_ex_id
                               LEFT JOIN ibmu.dor d2 ON s2.dor_id = d2.dor_id
                               LEFT JOIN ibmu.adm a2 ON d2.adm_id = a2.adm_id
                         WHERE     s1.kod = p_exit_station_code
                               AND s1.stan_id = sp.stan1_ex_id
                        UNION
                        SELECT CASE
                                   WHEN sp.stan1_ex_id = 0
                                   THEN
                                       at1.kod
                                       || st1.kod
                                   ELSE
                                       a2.kod
                                       || s2.kod
                               END    txt
                          FROM ibmu.stan        s1
                              ,ibmu.stik_punkt  sp
                               LEFT JOIN ibmu.stan1 st1 ON sp.stan1_os_id = st1.stan_id
                               LEFT JOIN ibmu.adm at1 ON st1.adm_id = at1.adm_id
                               LEFT JOIN ibmu.stan s2 ON s2.stan_id = sp.stan1_ex_id
                               LEFT JOIN ibmu.dor d2 ON s2.dor_id = d2.dor_id
                               LEFT JOIN ibmu.adm a2 ON d2.adm_id = a2.adm_id
                         WHERE     s1.kod = p_exit_station_code
                               AND s1.stan_id = sp.stan2_ex_id)
                 WHERE     rownum = 1
                       AND txt IS NOT NULL);

        RETURN z_out;
    EXCEPTION
        WHEN no_data_found
        THEN
            RETURN NULL;
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'p_exit_station_code IN'
                                               ,p_exit_station_code);
            logger_service.logger.append_param (l_params
                                               ,'RETURN z_out'
                                               ,z_out);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.get_entry_station_code'
                                            ,p_params => l_params);
            RETURN NULL;
    END get_entry_station_code;

    FUNCTION create_rqr (p_document IN smgs2_interface.t_smgs)
        RETURN VARCHAR2
    IS
        z_rqr_text             VARCHAR2 (350);
        z_exit_station_code    VARCHAR2 (8);
        z_entry_station_code   VARCHAR2 (8);
        z_source_stations_list VARCHAR2 (1024);
        l_params               logger_service.logger.tab_param;
        l_step                 VARCHAR2 (100);
    BEGIN
        FOR i IN 1 .. p_document.station.count
        /* smgs_role order must be 5,8,17,42,42,42,42  */
        LOOP
            l_step :=
                'FOR p_document.station '
                || i;
            z_source_stations_list :=
                z_source_stations_list
                || quote (i)
                || '. Station '
                || quote (p_document.station (i).code6)
                || ' with role '
                || quote (p_document.station (i).smgs_role);

            IF p_document.station (i).smgs_role IN ('17'
                                                   ,'42')
            THEN
                -- exit station
                z_exit_station_code :=
                    p_document.station (i).rw_admin
                    || p_document.station (i).code6;

                IF    z_rqr_text IS NULL
                   OR instr (z_rqr_text
                            ,z_exit_station_code) = 0
                THEN
                    z_rqr_text           :=
                        concatenate (z_rqr_text
                                    ,'/'
                                    ,z_exit_station_code);

                    /* Get entry station from IBMU tables*/
                    z_entry_station_code := get_entry_station_code (p_document.station (i).code6);

                    IF z_entry_station_code IS NULL
                    THEN
                        /* is not a border station */
                        raise_application_error (-20000
                                                ,replace (sass.get_tekst_in_lang (6535
                                                                                 ,NULL
                                                                                 ,v ('APP_USER'))
                                                         ,'%1'
                                                         ,p_document.station (i).name
                                                          || ' ('
                                                          || p_document.station (i).code6
                                                          || ')'));
                    END IF;

                    z_rqr_text           :=
                        z_rqr_text
                        || '/'
                        || z_entry_station_code;
                ELSE
                    vjs.log_debug ('SMGS2_VALIDATE.Create_RQR'
                                  ,'WARNING: Duplicates found in "Borders Exit Stations" (roles 17 or 42) list or station is not an EXIT station: '
                                   || quote (z_exit_station_code)
                                   || '. Continuing with RQR composing'
                                  ,'Stations list now: '
                                   || z_source_stations_list
                                   || ' and RQR list now: '
                                   || z_rqr_text
                                  ,'Waybill nr.: '
                                   || quote (p_document.smgs_number));
                END IF;
            END IF;
        END LOOP;

        l_step := 'LTRIM z_rqr_text';
        z_rqr_text :=
            ltrim (z_rqr_text
                  ,'/');

        IF z_rqr_text IS NULL
        THEN
            raise_application_error (-20000
                                    ,'SMGS number '
                                     || p_document.smgs_number
                                     || '. No border stations found');
        END IF;

        RETURN z_rqr_text;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.append_param (l_params
                                               ,'z_rqr_text'
                                               ,z_rqr_text);
            logger_service.logger.append_param (l_params
                                               ,'z_entry_station_code'
                                               ,z_entry_station_code);
            logger_service.logger.append_param (l_params
                                               ,'p_document.smgs_number'
                                               ,p_document.smgs_number);
            logger_service.logger.log_error (p_text   => 'Unable to create border stations sequence (RQR): '
                                                        || sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.create_rqr'
                                            ,p_params => l_params);
            RETURN NULL;
    END create_rqr;

    PROCEDURE save_document (p_document IN OUT smgs2_interface.t_smgs
                            ,p_message  IN OUT tb_validation_message)
    IS
        p_ymbrik_id              VARCHAR2 (36);
        p_group_id               VARCHAR2 (64);
        p_seanss_nr              VARCHAR2 (128) := edifact.utils.get_seansi_number;
        p_seanss_id              NUMBER;
        p_sn_in_out              NUMBER (1) := 2; --out
        p_sn_staatus             VARCHAR2 (6) := 'PORTAL';
        p_sn_tyyp                VARCHAR2 (6) := 'IFTMIN';
        p_sn_tyyp_ver            VARCHAR2 (3) := 'D';
        p_sn_tyyp_nr             VARCHAR2 (3) := '97A';
        p_sn_org                 VARCHAR2 (3) := 'UN';
        p_sn_ass_kood            VARCHAR2 (6) := 'OSJD';
        p_dokum_kood             VARCHAR2 (3) := '722';
        p_dokum_nimi             VARCHAR2 (35) := '';
        p_versioon               VARCHAR2 (25) := '2015.1';
        p_saad_funk_kood         NUMBER := '9';
        p_wagon_type             VARCHAR2 (2) := 'RR';
        p_kas_test               NUMBER (1) := NULL;

        p_wagon_edi_id           VARCHAR2 (64);
        p_container_edi_id       VARCHAR2 (64);
        l_equipment_edi_id       edifact.seadmed.id%TYPE;
        p_goods_edi_id           VARCHAR2 (64);
        p_participant_edi_id     VARCHAR2 (64);
        p_viide_id               VARCHAR2 (64);
        p_oht_kaup_id            edifact.oht_kaup.id%TYPE;

        z_sending_state_code     VARCHAR2 (2);
        z_destination_state_code VARCHAR2 (2);
        z_code                   VARCHAR2 (4);
        z_rqr_text               VARCHAR2 (350);
        z_count                  NUMBER;

        l_params                 logger_service.logger.tab_param;
        l_step                   VARCHAR2 (300);
    BEGIN
        l_step                 := 'begin';
        message                := tb_validation_message ();

        /* if edit mode then new record status is 4(parandus) and old record have a nonchanged status */
        l_step                 := 'if edit mode then new record status is 4(parandus) and old record have a nonchanged status';
        p_saad_funk_kood       := define_mode (p_document);

        /* ymbrik and seans id */
        l_step                 := 'ymbrik and seans id';
        p_seanss_id            :=
            edifact.utils.start_seanss ('PORTAL_in'
                                       ,p_seanss_nr);

        p_kas_test             := p_document.is_test;
        p_dokum_kood           := '722';

        IF     p_document.transportationstatus.is_reforwarding = 1
           AND p_document.transportationstatus.originalsmgsnumber IS NOT NULL
        THEN
            p_dokum_kood := 'ZWB';
        END IF;

        IF nvl (p_document.dokum_kood, 'x') = 'ZPN' -- for IFTMIN_PN
        THEN
            p_dokum_kood := p_document.dokum_kood;
        END IF;

        /* Data source. */
        l_step                 := 'Data source.';

        IF sys_context ('CLIENTCONTEXT'
                       ,'datasource') IN ('SK_XML'
                                         ,'PORTAL')
        THEN
            p_sn_staatus :=
                sys_context ('CLIENTCONTEXT'
                            ,'datasource');
        END IF;

        l_step                 := 'INSERT INTO edifact.ymbrik';

        INSERT INTO edifact.ymbrik (id
                                   ,seanss_id
                                   ,kas_test
                                   ,in_out
                                   ,staatus
                                   )
             VALUES (p_ymbrik_id
                    ,p_seanss_id
                    ,p_kas_test
                    ,'2'
                    ,'XML_T'
                    )
          RETURNING id
               INTO p_ymbrik_id;

        l_step                 := 'INSERT INTO edifact.grupp';

        INSERT INTO edifact.grupp (ymbrik_id
                                  ,sn_tyyp
                                  )
             VALUES (p_ymbrik_id
                    ,'IFTMIN'
                    )
          RETURNING id
               INTO p_group_id;

        l_step                 := 'INSERT INTO edifact.sonum';

        INSERT INTO edifact.sonum (grupp_id
                                  ,ymbrik_id
                                  ,sn_in_out
                                  ,sn_staatus
                                  ,sn_kuupaev
                                  ,sn_tyyp
                                  ,sn_tyyp_ver
                                  ,sn_tyyp_nr
                                  ,sn_org
                                  ,sn_ass_kood
                                  ,dokum_kood
                                  ,dokum_nimi
                                  ,saadetise_nr
                                  ,saad_funk_kood
                                  ,kes_laadis
                                  ,saad_liik
                                  ,prioriteet
                                  ,hange_ting
                                  ,vedaja_kood4
                                  ,versioon
                                  ,mrn_number
                                  )
             VALUES (p_group_id
                    ,p_ymbrik_id
                    ,nvl (p_document.sn_in_out, p_sn_in_out)
                    ,p_sn_staatus
                    ,nvl (p_document.created_at, sysdate)
                    ,p_sn_tyyp
                    ,p_sn_tyyp_ver
                    ,p_sn_tyyp_nr
                    ,p_sn_org
                    ,p_sn_ass_kood
                    ,p_dokum_kood
                    ,p_dokum_nimi
                    ,p_document.smgs_number
                    ,p_saad_funk_kood
                    ,p_document.who_loaded
                    ,p_document.smgs_type
                    ,''
                    ,''
                    ,p_document.carrier_code4
                    ,p_versioon
                    ,p_document.mrn_number
                    )
          RETURNING id
               INTO p_document.edi_id;

        p_document.data_source := 'EDIFACT';

        IF p_document.wagon.count > 0
        THEN
            FOR i IN 1 .. p_document.wagon.count
            LOOP
                l_step :=
                    'FOR p_document.wagon '
                    || i
                    || ' and wagons';

                -- wagons
                INSERT INTO edifact.vagun (sonum_id
                                          ,jrk_nr
                                          ,v_tyyp
                                          ,vagun_nr
                                          ,tyhi_laaditud
                                          ,lisa_atribuut
                                          ,tara_yhik
                                          ,tara_kaal
                                          ,kandevoime_yhik
                                          ,kandevoime
                                          ,teljed
                                          ,kaubakaalu_yhik
                                          ,kaubakaal
                                          ,kalibreerimine_kood
                                          ,omaniku_nimi
                                          ,tarnija_kood
                                          )
                     VALUES (p_document.edi_id
                            ,p_document.wagon (i).position
                            ,p_wagon_type
                            ,p_document.wagon (i).wagon_nr
                            ,decode (nvl (p_document.wagon (i).goods_weight, 0), 0, 4, 5)
                            ,NULL
                            ,'TNE'
                            ,p_document.wagon (i).net_weight
                            ,'TNE'
                            ,p_document.wagon (i).capacity
                            ,p_document.wagon (i).axis
                            ,'KGM'
                            ,p_document.wagon (i).goods_weight
                            ,p_document.wagon (i).kalibr_code
                            ,p_document.wagon (i).owner_name
                            ,decode (p_document.wagon (i).provider,  0, 'О',  1, 'П',  NULL)
                            )
                  RETURNING id
                       INTO p_wagon_edi_id;

                -- Insert into KOGUS_KAAL goods_weight
                l_step :=
                    'FOR p_document.wagon '
                    || i
                    || ' and Insert into KOGUS_KAAL goods_weight';

                INSERT INTO edifact.kogus_kaal (sonum_id
                                               ,parent_name
                                               ,parent_id
                                               ,vaartus
                                               ,yhik
                                               ,tunnus
                                               ,liik
                                               )
                     VALUES (p_document.edi_id
                            ,'VAGUN'
                            ,p_wagon_edi_id
                            ,p_document.wagon (i).goods_weight
                            ,'KGM'
                            ,'WT'
                            ,'AAD'
                            );

                -- Insert into KOGUS_KAAL net_weight
                l_step :=
                    'FOR p_document.wagon '
                    || i
                    || ' and Insert into KOGUS_KAAL net_weight';

                INSERT INTO edifact.kogus_kaal (sonum_id
                                               ,parent_name
                                               ,parent_id
                                               ,vaartus
                                               ,yhik
                                               ,tunnus
                                               ,liik
                                               )
                     VALUES (p_document.edi_id
                            ,'VAGUN'
                            ,p_wagon_edi_id
                            ,p_document.wagon (i).net_weight
                            ,'TNE'
                            ,'WT'
                            ,'T'
                            );

                -- Insert into KOGUS_KAAL capacity
                l_step :=
                    'FOR p_document.wagon '
                    || i
                    || ' and Insert into KOGUS_KAAL capacity';

                INSERT INTO edifact.kogus_kaal (sonum_id
                                               ,parent_name
                                               ,parent_id
                                               ,vaartus
                                               ,yhik
                                               ,tunnus
                                               )
                     VALUES (p_document.edi_id
                            ,'VAGUN'
                            ,p_wagon_edi_id
                            ,p_document.wagon (i).capacity
                            ,'TNE'
                            ,'SV'
                            );

                -- Insert into KOGUS_KAAL axis
                l_step :=
                    'FOR p_document.wagon '
                    || i
                    || ' and Insert into KOGUS_KAAL axis';

                INSERT INTO edifact.kogus_kaal (sonum_id
                                               ,parent_name
                                               ,parent_id
                                               ,vaartus
                                               ,yhik
                                               ,tunnus
                                               )
                     VALUES (p_document.edi_id
                            ,'VAGUN'
                            ,p_wagon_edi_id
                            ,p_document.wagon (i).axis
                            ,'PCE'
                            ,'NAX'
                            );

                l_step :=
                    'FOR p_document.wagon '
                    || i
                    || ' and INSERT INTO edifact.isik';

                INSERT INTO edifact.isik (sonum_id
                                         ,vagun_id
                                         ,tunnus
                                         ,ident_kood
                                         ,ident_tunnus
                                         ,ident_agent
                                         ,nimi
                                         )
                     VALUES (p_document.edi_id
                            ,p_wagon_edi_id
                            ,'CW'
                            ,p_document.wagon (i).rw_admin
                             || '/'
                             || decode (p_document.wagon (i).provider,  0, 'О',  1, 'П',  NULL)
                            ,NULL
                            ,12
                            ,p_document.wagon (i).owner_name
                            );

                /* 21.06.2016 by Ale_x - Added "p_document.wagon (i).LEAD (j).station" attribute saving into "JAAM_KOOD6" field */

                -- leads
                FOR j IN 1 .. p_document.wagon (i).lead.count
                LOOP
                    l_step :=
                        'FOR p_document.wagon '
                        || i
                        || ' and FOR LEAD '
                        || j;

                    INSERT INTO edifact.plommid (sonum_id
                                                ,seadmed_id
                                                ,vagun_id
                                                ,plommi_nr
                                                ,kes_pani
                                                ,plommide_arv
                                                ,jaam_kood6
                                                )
                         VALUES (p_document.edi_id
                                ,NULL
                                ,p_wagon_edi_id
                                ,p_document.wagon (i).lead (j).lead_nr
                                ,p_document.wagon (i).lead (j).owner
                                ,nvl (p_document.wagon (i).lead (j).amount, 1)
                                ,p_document.wagon (i).lead (j).station
                                );
                END LOOP;

                -- containers
                FOR j IN 1 .. p_document.wagon (i).container.count
                LOOP
                    l_step :=
                        'FOR p_document.wagon '
                        || i
                        || ' and FOR container '
                        || j
                        || ' and INSERT INTO edifact.seadmed';

                    INSERT INTO edifact.seadmed (sonum_id
                                                ,vagun_id
                                                ,tunnus
                                                ,konteineri_nr
                                                ,aluste_arv
                                                ,konteineri_pikkus
                                                ,pikkuse_yhik
                                                ,vaguninumber
                                                ,seadme_tyyp
                                                ,omaniku_vorm
                                                ,omanik
                                                )
                         VALUES (p_document.edi_id
                                ,p_wagon_edi_id
                                ,'CN'
                                ,p_document.wagon (i).container (j).container_nr
                                ,j
                                ,p_document.wagon (i).container (j).length
                                ,'FOT'
                                ,p_document.wagon (i).wagon_nr
                                ,p_document.wagon (i).container (j).type
                                ,p_document.wagon (i).container (j).ownership_form
                                ,p_document.wagon (i).container (j).rw_admin
                                )
                      RETURNING id
                           INTO p_container_edi_id;

                    l_step :=
                        'FOR p_document.wagon '
                        || i
                        || ' and FOR container '
                        || j
                        || ' and vaartus p_document.wagon (i).container (j).net_weight';

                    INSERT INTO edifact.kogus_kaal (sonum_id
                                                   ,parent_name
                                                   ,parent_id
                                                   ,tunnus
                                                   ,liik
                                                   ,yhik
                                                   ,vaartus
                                                   )
                         VALUES (p_document.edi_id
                                ,'SEADMED'
                                ,p_container_edi_id
                                ,'AAI'
                                ,'T'
                                ,'KGM'
                                ,p_document.wagon (i).container (j).net_weight
                                );

                    l_step :=
                        'FOR p_document.wagon '
                        || i
                        || ' and FOR container '
                        || j
                        || ' and vaartus p_document.wagon (i).container (j).goods_weight';

                    INSERT INTO edifact.kogus_kaal (sonum_id
                                                   ,parent_name
                                                   ,parent_id
                                                   ,tunnus
                                                   ,liik
                                                   ,yhik
                                                   ,vaartus
                                                   )
                         VALUES (p_document.edi_id
                                ,'SEADMED'
                                ,p_container_edi_id
                                ,'WT'
                                ,'AAD'
                                ,'KGM'
                                ,p_document.wagon (i).container (j).goods_weight
                                );

                    l_step :=
                        'FOR p_document.wagon '
                        || i
                        || ' and FOR container '
                        || j
                        || ' and vaartus NVL (p_document.wagon (i).container (j).net_weight, 0) + NVL (p_document.wagon (i).container (j).goods_weight, 0)';

                    INSERT INTO edifact.kogus_kaal (sonum_id
                                                   ,parent_name
                                                   ,parent_id
                                                   ,tunnus
                                                   ,liik
                                                   ,yhik
                                                   ,vaartus
                                                   )
                         VALUES (p_document.edi_id
                                ,'SEADMED'
                                ,p_container_edi_id
                                ,'AAE'
                                ,'G'
                                ,'KGM'
                                ,nvl (p_document.wagon (i).container (j).net_weight, 0) + nvl (p_document.wagon (i).container (j).goods_weight, 0)
                                );

                    -- containers leads
                    IF p_document.wagon (i).container (j).lead.count > 0
                    THEN
                        FOR k IN 1 .. p_document.wagon (i).container (j).lead.count
                        LOOP
                            l_step :=
                                'FOR p_document.wagon '
                                || i
                                || ' and FOR container '
                                || j
                                || ' and LEAD '
                                || k;

                            /* 21.06.2016 by AB - Added "p_document.wagon (i).LEAD (j).station" attribute saving into "JAAM_KOOD6" field */
                            INSERT INTO edifact.plommid (sonum_id
                                                        ,seadmed_id
                                                        ,vagun_id
                                                        ,plommi_nr
                                                        ,kes_pani
                                                        ,plommide_arv
                                                        ,jaam_kood6
                                                        )
                                 VALUES (p_document.edi_id
                                        ,p_container_edi_id
                                        ,p_wagon_edi_id
                                        ,p_document.wagon (i).container (j).lead (k).lead_nr
                                        ,p_document.wagon (i).container (j).lead (k).owner
                                        ,nvl (p_document.wagon (i).container (j).lead (k).amount, 1)
                                        ,p_document.wagon (i).container (j).lead (k).station
                                        );
                        END LOOP;
                    END IF;
                END LOOP;

                -- equipment (non-containers)
                FOR j IN 1 .. p_document.wagon (i).equipment.count
                LOOP
                    l_step :=
                        'FOR p_document.wagon '
                        || i
                        || ' and FOR equipment '
                        || j
                        || ' and INSERT INTO edifact.seadmed';

                    INSERT INTO edifact.seadmed (sonum_id
                                                ,vagun_id
                                                ,tunnus
                                                ,konteineri_nr
                                                ,aluste_arv
                                                ,konteineri_pikkus
                                                ,pikkuse_yhik
                                                ,vaguninumber
                                                ,seadme_tyyp
                                                ,omaniku_vorm
                                                ,omanik
                                                )
                         VALUES (p_document.edi_id
                                ,p_wagon_edi_id
                                ,nvl (p_document.wagon (i).equipment (j).equipmenttype_text, 'EFP')
                                ,nvl (p_document.wagon (i).equipment (j).equipment_nr, '0')
                                ,j
                                ,NULL
                                ,NULL
                                ,p_document.wagon (i).wagon_nr
                                ,NULL
                                ,p_document.wagon (i).equipment (j).ownership_form
                                ,NULL
                                )
                      RETURNING id
                           INTO l_equipment_edi_id;

                    l_step :=
                        'FOR p_document.wagon '
                        || i
                        || ' and FOR equipment '
                        || j
                        || ' and vaartus p_document.wagon (i).equipment (j).tare_weight';

                    INSERT INTO edifact.kogus_kaal (sonum_id
                                                   ,parent_name
                                                   ,parent_id
                                                   ,tunnus
                                                   ,liik
                                                   ,yhik
                                                   ,vaartus
                                                   )
                         VALUES (p_document.edi_id
                                ,'SEADMED'
                                ,l_equipment_edi_id
                                ,'AAZ'
                                ,'T'
                                ,'KGM'
                                ,p_document.wagon (i).equipment (j).tare_weight
                                );

                    l_step :=
                        'FOR p_document.wagon '
                        || i
                        || ' and FOR equipment '
                        || j
                        || ' and tekst p_document.wagon (i).equipment (j).equipmenttype_descr';

                    INSERT INTO edifact.tekst (sonum_id
                                              ,tunnus
                                              ,tekst
                                              ,parent_name
                                              ,parent_id
                                              )
                         VALUES (p_document.edi_id
                                ,'LOI'
                                ,remove_line_break (substr (p_document.wagon (i).equipment (j).equipmenttype_descr
                                                           ,1
                                                           ,350))
                                ,'SEADMED'
                                ,l_equipment_edi_id
                                );
                END LOOP;

                -- previous goods
                -- the text part goes into the edifact.tekst table...
                l_step :=
                    'FOR p_document.wagon '
                    || i
                    || ' and previous goods insert edifact.tekst';

                INSERT INTO edifact.tekst (sonum_id
                                          ,tunnus
                                          ,tekst
                                          ,parent_name
                                          ,parent_id
                                          )
                     VALUES (p_document.edi_id
                            ,'AAA'
                            ,remove_line_break (substr (p_document.wagon (i).prev_desc
                                                       ,1
                                                       ,350))
                            ,'VAGUN'
                            ,p_wagon_edi_id
                            );

                -- ...but codes go into the edifact.eelmine_kaup table
                l_step :=
                    'FOR p_document.wagon '
                    || i
                    || ' and previous goods insert edifact.eelmine_kaup';

                INSERT INTO edifact.eelmine_kaup (sonum_id
                                                 ,vagun_id
                                                 ,eelmine_sonum_id
                                                 ,gng_kood
                                                 ,etsng_kood
                                                 )
                     VALUES (p_document.edi_id
                            ,p_wagon_edi_id
                            ,NULL
                            ,substr (p_document.wagon (i).prev_gng
                                    ,1
                                    ,12)
                            ,substr (p_document.wagon (i).prev_etsng
                                    ,1
                                    ,6)
                            );

                IF nvl (p_document.dokum_kood, 'x') = 'ZPN' -- for IFTMIN_PN
                THEN
                    -- previous dangergoods description, IFTMIN_PN
                    -- the text part goes into the edifact.tekst table...
                    IF nvl (p_document.wagon (i).prev_danger_desc, '.') > '.'
                    THEN
                        l_step :=
                            'FOR p_document.wagon '
                            || i
                            || ' and previous previous dangergoods description insert edifact.tekst';

                        INSERT INTO edifact.tekst (sonum_id
                                                  ,tunnus
                                                  ,tekst
                                                  ,parent_name
                                                  ,parent_id
                                                  )
                             VALUES (p_document.edi_id
                                    ,'AAD'
                                    ,remove_line_break (substr (p_document.wagon (i).prev_danger_desc
                                                               ,1
                                                               ,350))
                                    ,'VAGUN'
                                    ,p_wagon_edi_id
                                    );
                    END IF;

                    -- Wagon notes, IFTMIN_PN
                    -- the text part goes into the edifact.tekst table...
                    l_step :=
                        'FOR p_document.wagon '
                        || i
                        || ' and notes insert edifact.tekst';

                    INSERT INTO edifact.tekst (sonum_id
                                              ,tunnus
                                              ,tekst
                                              ,parent_name
                                              ,parent_id
                                              )
                         VALUES (p_document.edi_id
                                ,'ZRR'
                                ,remove_line_break (p_document.wagon (i).notes)
                                ,'VAGUN'
                                ,p_wagon_edi_id
                                );
                END IF;
            END LOOP;
        END IF;

        IF p_document.participant.count > 0
        THEN
            FOR i IN 1 .. p_document.participant.count
            LOOP
                l_step :=
                    'FOR p_document.participant '
                    || i;

                IF p_document.participant (i).smgs_role = 'CA'
                THEN
                    /* search Z13 code */
                    z_code := NULL;

                    FOR j IN 1 .. p_document.participant (i).codes.count
                    LOOP
                        IF p_document.participant (i).codes (j).code_type = 'Z13'
                        THEN
                            z_code := p_document.participant (i).codes (j).code_value;
                        END IF;
                    END LOOP;
                END IF;

                l_step :=
                    'FOR p_document.participant '
                    || i
                    || ' and INSERT INTO edifact.isik';

                INSERT INTO edifact.isik (sonum_id
                                         ,vanem_id
                                         ,vagun_id
                                         ,tunnus
                                         ,reg_kood
                                         ,nimi
                                         ,tanav
                                         ,linn
                                         ,maakond
                                         ,indeks
                                         ,riik
                                         ,saatja_nimi
                                         ,telefon
                                         ,faks
                                         ,e_post
                                         ,n1
                                         ,n2
                                         ,n3
                                         ,n4
                                         ,n5
                                         ,s1
                                         ,s2
                                         ,s3
                                         ,s4
                                         ,allkiri
                                         ,e_tunnus
                                         ,kliendi_kood4
                                         ,jkrnr
                                         ,ident_kood
                                         ,ident_tunnus
                                         )
                     VALUES (p_document.edi_id
                            ,NULL
                            ,NULL
                            ,p_document.participant (i).smgs_role
                            ,p_document.participant (i).reg_code
                            ,p_document.participant (i).name
                            ,p_document.participant (i).street
                            ,p_document.participant (i).city
                            ,NULL
                            ,p_document.participant (i).zipcode
                            ,p_document.participant (i).state
                            ,p_document.participant (i).agent
                            ,p_document.participant (i).telefon
                            ,p_document.participant (i).fax
                            ,p_document.participant (i).email
                            ,NULL
                            ,NULL
                            ,NULL
                            ,NULL
                            ,NULL
                            ,NULL
                            ,NULL
                            ,NULL
                            ,NULL
                            ,p_document.participant (i).signature
                            ,p_document.participant (i).e_document
                            ,p_document.participant (i).code4
                            ,i
                            ,decode (p_document.participant (i).smgs_role, 'CA', z_code, NULL)
                            ,decode (p_document.participant (i).smgs_role, 'CA', 'Z13', NULL)
                            )
                  RETURNING id
                       INTO p_participant_edi_id;

                /* save participant codes*/
                FOR j IN 1 .. p_document.participant (i).codes.count
                LOOP
                    l_step :=
                        'FOR p_document.participant '
                        || i
                        || ' and codes '
                        || j;

                    INSERT INTO edifact.isiku_lisaandmed (isik_id
                                                         ,sonum_id
                                                         ,tunnus
                                                         ,lisainfo
                                                         )
                         VALUES (p_participant_edi_id
                                ,p_document.edi_id
                                ,substr (p_document.participant (i).codes (j).code_type
                                        ,1
                                        ,25)
                                ,substr (p_document.participant (i).codes (j).code_value
                                        ,1
                                        ,256)
                                );
                END LOOP;

                IF p_document.participant (i).smgs_role = 'CA'
                THEN
                    IF nvl (smgs.dokum_kood, 'x') <> 'ZPN' -- exclusion for IFTMIN_PN
                    THEN
                        -- carriers region
                        IF p_document.participant (i).carrier_region.count > 0
                        THEN
                            l_step :=
                                'FOR p_document.participant '
                                || i
                                || ' and smgs_role = CA and tunnus 32';

                            INSERT INTO edifact.jaam (sonum_id
                                                     ,tunnus
                                                     ,jaama_kood
                                                     ,adm_kood
                                                     ,klassifikaator
                                                     ,vast_kood
                                                     ,jaama_nimi
                                                     ,parent_name
                                                     ,parent_id
                                                     )
                                 VALUES (p_document.edi_id
                                        ,32
                                        ,p_document.participant (i).carrier_region (1).code6
                                        ,p_document.participant (i).carrier_region (1).rw_admin
                                        ,37
                                        ,288
                                        ,p_document.participant (i).carrier_region (1).name
                                        ,'ISIK'
                                        ,p_participant_edi_id
                                        );

                            l_step :=
                                'FOR p_document.participant '
                                || i
                                || ' and smgs_role = CA and tunnus 56';

                            INSERT INTO edifact.jaam (sonum_id
                                                     ,tunnus
                                                     ,jaama_kood
                                                     ,adm_kood
                                                     ,klassifikaator
                                                     ,vast_kood
                                                     ,jaama_nimi
                                                     ,parent_name
                                                     ,parent_id
                                                     )
                                 VALUES (p_document.edi_id
                                        ,56
                                        ,p_document.participant (i).carrier_region (2).code6
                                        ,p_document.participant (i).carrier_region (2).rw_admin
                                        ,37
                                        ,288
                                        ,p_document.participant (i).carrier_region (2).name
                                        ,'ISIK'
                                        ,p_participant_edi_id
                                        );
                        ELSE
                            l_step   :=
                                'FOR p_document.participant '
                                || i
                                || ' and smgs_role = CA';
                            l_params := logger_service.logger.gc_empty_tab_param;
                            logger_service.logger.append_param (l_params
                                                               ,'l_step'
                                                               ,l_step);
                            logger_service.logger.append_param (l_params
                                                               ,'p_document.smgs_number'
                                                               ,p_document.smgs_number);
                            logger_service.logger.log_info (p_text   => 'For CA no carrier_region !'
                                                           ,p_scope  => 'spv.'
                                                                       || $$plsql_unit
                                                                       || '.save_document - p_document.participant (i).smgs_role = CA'
                                                           ,p_params => l_params);
                        END IF;
                    END IF;
                ELSIF p_document.participant (i).smgs_role = 'GS'
                THEN
                    -- expeditors contract

                    IF p_document.participant (i).documents.count > 0
                    THEN
                        l_step :=
                            'FOR p_document.participant '
                            || i
                            || ' and smgs_role = GS and INSERT INTO edifact.viide';

                        INSERT INTO edifact.viide (sonum_id
                                                  ,tunnus
                                                  ,viitenumber
                                                  ,parent_name
                                                  ,parent_id
                                                  )
                             VALUES (p_document.edi_id
                                    ,'AEK'
                                    ,p_document.participant (i).documents (1).docnumber
                                    ,'ISIK'
                                    ,p_participant_edi_id
                                    )
                          RETURNING id
                               INTO p_viide_id;

                        l_step :=
                            'FOR p_document.participant '
                            || i
                            || ' and smgs_role = GS and INSERT INTO edifact.aeg';

                        INSERT INTO edifact.aeg (sonum_id
                                                ,parent_name
                                                ,parent_id
                                                ,tunnus
                                                ,aeg
                                                ,vast_kood
                                                )
                             VALUES (p_document.edi_id
                                    ,'VIIDE'
                                    ,p_viide_id
                                    ,'92'
                                    ,p_document.participant (i).documents (1).created_at
                                    ,203
                                    );
                    END IF;
                END IF;
            END LOOP;

            -- create expeditor - undertacer relation
            -- search undertacker
            FOR i IN 1 .. p_document.participant.count
            LOOP
                IF p_document.participant (i).smgs_role = 'GS'
                THEN
                    FOR j IN 1 .. p_document.participant.count
                    LOOP
                        IF p_document.participant (i).parent_participant_id = p_document.participant (j).participant_id
                        THEN
                            DECLARE
                                p_undertaker_id VARCHAR2 (32);
                            BEGIN
                                l_step :=
                                    'FOR p_document.participant '
                                    || i
                                    || ' and smgs_role = GS and SELECT id INTO p_undertaker_id';

                                SELECT id
                                  INTO p_undertaker_id
                                  FROM edifact.isik
                                 WHERE     sonum_id = p_document.edi_id
                                       AND tunnus = 'CA'
                                       AND nimi = p_document.participant (j).name
                                       AND rownum = 1;

                                l_step :=
                                    'FOR p_document.participant '
                                    || i
                                    || ' and smgs_role = GS and UPDATE edifact.isik';

                                UPDATE edifact.isik
                                   SET vanem_id = p_undertaker_id
                                 WHERE     sonum_id = p_document.edi_id
                                       AND tunnus = 'GS'
                                       AND nimi = p_document.participant (i).name /* if one expeditor used for two undertacers next row correct it*/
                                       AND jkrnr = i;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_params := logger_service.logger.gc_empty_tab_param;
                                    logger_service.logger.append_param (l_params
                                                                       ,'l_step'
                                                                       ,l_step);
                                    logger_service.logger.log_error (p_text   => sqlerrm
                                                                    ,p_scope  => 'spv.'
                                                                                || $$plsql_unit
                                                                                || '.save_document - undertaker'
                                                                    ,p_params => l_params);
                            END;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;

        -- stations
        IF p_document.station.count > 0
        THEN
            FOR i IN 1 .. p_document.station.count
            LOOP
                l_step :=
                    'FOR p_document.station '
                    || i
                    || ' and INSERT INTO edifact.jaam';

                INSERT INTO edifact.jaam (sonum_id
                                         ,makse_id
                                         ,teenus_id
                                         ,riik
                                         ,jrk_nr
                                         ,tunnus
                                         ,loc_kood
                                         ,jaama_kood
                                         ,adm_kood
                                         ,klassifikaator
                                         ,vast_kood
                                         ,jaama_nimi
                                         ,vedaja
                                         )
                     VALUES (p_document.edi_id
                            ,NULL
                            ,NULL
                            ,NULL
                            ,p_document.station (i).position
                            ,p_document.station (i).smgs_role
                            ,NULL
                            ,p_document.station (i).code6
                            ,p_document.station (i).rw_admin
                            ,'37'
                            ,'288'
                            ,p_document.station (i).name
                            ,NULL
                            );

                l_step :=
                    'FOR p_document.station '
                    || i
                    || ' and state_code';

                IF p_document.station (i).smgs_role = '5' /* sending station */
                THEN
                    /* 67 - Estonia state ID*/
                    z_sending_state_code := nvl (get_riik_code (p_document.station (i).code6), 'EE');
                ELSIF p_document.station (i).smgs_role = '8' /* destination station */
                THEN
                    z_destination_state_code := get_riik_code (p_document.station (i).code6);
                END IF;
            END LOOP;
        END IF;

        /*stationDeparture   -- NOT USED ?*/
        l_step                 := 'stationDeparture';

        IF p_document.stationdeparture.code6 IS NOT NULL
        THEN
            INSERT INTO edifact.jaam (sonum_id
                                     ,makse_id
                                     ,teenus_id
                                     ,riik
                                     ,jrk_nr
                                     ,tunnus
                                     ,loc_kood
                                     ,jaama_kood
                                     ,adm_kood
                                     ,klassifikaator
                                     ,vast_kood
                                     ,jaama_nimi
                                     ,vedaja
                                     )
                 VALUES (p_document.edi_id
                        ,NULL
                        ,NULL
                        ,NULL
                        ,p_document.stationdeparture.position
                        ,'5'
                        ,NULL
                        ,p_document.stationdeparture.code6
                        ,p_document.stationdeparture.rw_admin
                        ,'37'
                        ,'288'
                        ,p_document.stationdeparture.name
                        ,NULL
                        );
        END IF;

        /*stationDestination  - NOT USED ?*/
        l_step                 := 'stationDestination';

        IF p_document.stationdestination.code6 IS NOT NULL
        THEN
            INSERT INTO edifact.jaam (sonum_id
                                     ,makse_id
                                     ,teenus_id
                                     ,riik
                                     ,jrk_nr
                                     ,tunnus
                                     ,loc_kood
                                     ,jaama_kood
                                     ,adm_kood
                                     ,klassifikaator
                                     ,vast_kood
                                     ,jaama_nimi
                                     ,vedaja
                                     )
                 VALUES (p_document.edi_id
                        ,NULL
                        ,NULL
                        ,NULL
                        ,p_document.stationdestination.position
                        ,'8'
                        ,NULL
                        ,p_document.stationdestination.code6
                        ,p_document.stationdestination.rw_admin
                        ,'37'
                        ,'288'
                        ,p_document.stationdestination.name
                        ,NULL
                        );
        END IF;

        /* border - NOT USED?*/
        BEGIN
            IF p_document.border.count > 0
            THEN
                FOR i IN 1 .. p_document.border.count
                LOOP
                    FOR j IN 1 .. p_document.border (i).count
                    LOOP
                        l_step :=
                            'FOR p_document.border '
                            || i
                            || ' and border (i) '
                            || j
                            || ' and INSERT INTO edifact.jaam';

                        INSERT INTO edifact.jaam (sonum_id
                                                 ,makse_id
                                                 ,teenus_id
                                                 ,riik
                                                 ,jrk_nr
                                                 ,tunnus
                                                 ,loc_kood
                                                 ,jaama_kood
                                                 ,adm_kood
                                                 ,klassifikaator
                                                 ,vast_kood
                                                 ,jaama_nimi
                                                 ,vedaja
                                                 )
                             VALUES (p_document.edi_id
                                    ,NULL
                                    ,NULL
                                    ,NULL
                                    ,p_document.border (i) (j).position
                                    ,p_document.border (i) (j).smgs_role
                                    ,NULL
                                    ,p_document.border (i) (j).code6
                                    ,p_document.border (i) (j).rw_admin
                                    ,'37'
                                    ,'288'
                                    ,p_document.border (i) (j).name
                                    ,NULL
                                    );

                        l_step :=
                            'FOR p_document.border '
                            || i
                            || ' and border (i) '
                            || j
                            || ' and state_code';

                        IF p_document.border (i) (j).smgs_role = '5' /* sending station */
                        THEN
                            /* 67 - Estonia state ID*/
                            z_sending_state_code := nvl (get_riik_code (p_document.border (i) (j).code6), 'EE');
                        ELSIF p_document.border (i) (j).smgs_role = '8' /* destination station */
                        THEN
                            z_destination_state_code := get_riik_code (p_document.border (i) (j).code6);
                        END IF;
                    END LOOP;
                END LOOP;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.save_document - border'
                                                ,p_params => l_params);
        END;

        -- goods
        IF p_document.goods.count > 0
        THEN
            FOR i IN 1 .. p_document.goods.count
            LOOP
                l_step   :=
                    'FOR p_document.goods '
                    || i
                    || ' and INSERT INTO edifact.kaup';

                INSERT INTO edifact.kaup (sonum_id
                                         ,positsioon
                                         ,kauba_kood
                                         ,etsng_kood
                                         ,klassi_tyyp
                                         ,kl_kaal_yhik
                                         ,kl_kaal_vaartus
                                         ,rt_kaal_yhik
                                         ,rt_kaal_vaartus
                                         ,kas_ohtlik
                                         )
                     VALUES (p_document.edi_id
                            ,p_document.goods (i).position
                            ,p_document.goods (i).gng
                            ,p_document.goods (i).etsng
                            ,'ET'
                            ,NULL
                            , --'KGM',
                             NULL
                            , --p_document.goods (i).client_weight,
                             'KGM'
                            ,p_document.goods (i).railway_weight
                            ,CASE
                                 WHEN    p_document.goods (i).danger_code IS NULL
                                      OR p_document.goods (i).danger_crash_card IS NULL
                                      OR p_document.goods (i).danger_un_code IS NULL
                                 THEN
                                     NULL
                                 ELSE
                                     p_document.goods (i).danger_code
                             END
                            )
                  RETURNING id
                       INTO p_goods_edi_id;

                -- Insert into KOGUS_KAAL railway_weight
                l_step   :=
                    'FOR p_document.goods '
                    || i
                    || ' and Insert into KOGUS_KAAL railway_weight';

                INSERT INTO edifact.kogus_kaal (sonum_id
                                               ,parent_name
                                               ,parent_id
                                               ,vaartus
                                               ,yhik
                                               ,tunnus
                                               ,liik
                                               )
                     VALUES (p_document.edi_id
                            ,'KAUP'
                            ,p_goods_edi_id
                            ,p_document.goods (i).railway_weight
                            ,'KGM'
                            ,'WT'
                            ,'G'
                            );

                IF p_document.smgs_type <> 4
                THEN
                    --  Insert into KOGUS_KAAL railway_weight if is not containers and transport. gadgets.
                    l_step :=
                        'FOR p_document.goods '
                        || i
                        || ' and Insert into KOGUS_KAAL railway_weight if is not containers and transport. gadgets.';

                    INSERT INTO edifact.kogus_kaal (sonum_id
                                                   ,parent_name
                                                   ,parent_id
                                                   ,vaartus
                                                   ,yhik
                                                   ,tunnus
                                                   ,liik
                                                   )
                         VALUES (p_document.edi_id
                                ,'KAUP'
                                ,p_goods_edi_id
                                ,p_document.goods (i).railway_weight
                                ,'KGM'
                                ,'AAH'
                                ,'G'
                                );
                END IF;

                -- Insert into KOGUS_KAAL client_weight
                l_step   :=
                    'FOR p_document.goods '
                    || i
                    || ' and Insert into KOGUS_KAAL client_weight';

                INSERT INTO edifact.kogus_kaal (sonum_id
                                               ,parent_name
                                               ,parent_id
                                               ,vaartus
                                               ,yhik
                                               ,tunnus
                                               ,liik
                                               )
                     VALUES (p_document.edi_id
                            ,'KAUP'
                            ,p_goods_edi_id
                            ,p_document.goods (i).client_weight
                            ,'KGM'
                            ,'ASW'
                            ,'AEC'
                            );

                /* Kauba riigid */
                l_step   :=
                    'FOR p_document.goods '
                    || i
                    || ' and Kauba riigid';
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.append_param (l_params
                                                   ,'p_document.goods (i).state_dispatch'
                                                   ,p_document.goods (i).state_dispatch);
                logger_service.logger.log_info (p_text   => 'Kauba riigid'
                                               ,p_scope  => 'spv.'
                                                           || $$plsql_unit
                                                           || '.save_document - Kauba riigid'
                                               ,p_params => l_params);

                BEGIN
                    l_step :=
                        'FOR p_document.goods '
                        || i
                        || ' and Kauba riigid and z_sending_state_code';

                    INSERT INTO edifact.kauba_riik (kaup_id
                                                   ,tunnus
                                                   ,riigi_kood
                                                   ,klassifikaator
                                                   ,vast_kood
                                                   )
                         VALUES (p_goods_edi_id
                                ,35
                                ,nvl (p_document.goods (i).state_dispatch, z_sending_state_code)
                                ,162
                                ,5
                                );

                    l_step :=
                        'FOR p_document.goods '
                        || i
                        || ' and Kauba riigid and z_destination_state_code';

                    INSERT INTO edifact.kauba_riik (kaup_id
                                                   ,tunnus
                                                   ,riigi_kood
                                                   ,klassifikaator
                                                   ,vast_kood
                                                   )
                         VALUES (p_goods_edi_id
                                ,28
                                ,nvl (p_document.goods (i).state_destination, z_destination_state_code)
                                ,162
                                ,5
                                );
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_params := logger_service.logger.gc_empty_tab_param;
                        logger_service.logger.append_param (l_params
                                                           ,'l_step'
                                                           ,l_step);
                        logger_service.logger.log_error (p_text   => sqlerrm
                                                        ,p_scope  => 'spv.'
                                                                    || $$plsql_unit
                                                                    || '.save_document - Kauba riigid'
                                                        ,p_params => l_params);
                END;

                -- danger goods
                IF    p_document.goods (i).danger_crash_card IS NOT NULL
                   OR p_document.goods (i).danger_un_code IS NOT NULL
                THEN
                    l_step :=
                        'FOR p_document.goods '
                        || i
                        || ' and danger goods and INSERT INTO edifact.oht_kaup';

                    INSERT INTO edifact.oht_kaup (sonum_id
                                                 ,kaup_id
                                                 ,av_kaardi_nr
                                                 ,un_kood
                                                 ,yl_sildi_nr
                                                 ,al_sildi_nr
                                                 ,pakendi_grupi_kood
                                                 ,kood
                                                 ,klass
                                                 ,markeering1
                                                 )
                         VALUES (p_document.edi_id
                                ,p_goods_edi_id
                                ,p_document.goods (i).danger_crash_card
                                ,p_document.goods (i).danger_un_code
                                ,NULL
                                ,NULL
                                ,p_document.goods (i).danger_packing_group
                                ,p_document.goods (i).danger_code
                                ,substr (p_document.goods (i).danger_class
                                        ,1
                                        ,5)
                                ,p_document.goods (i).danger_sign
                                )
                      RETURNING id
                           INTO p_oht_kaup_id;

                    -- insert text AAD  (danger name description)
                    l_step :=
                        'FOR p_document.goods '
                        || i
                        || ' and danger goods and INSERT INTO edifact.tekst';

                    INSERT INTO edifact.tekst (sonum_id
                                              ,kaup_id
                                              ,oht_kaup_id
                                              ,toll_id
                                              ,seadmed_id
                                              ,tunnus
                                              ,tekst
                                              ,t1
                                              ,t2
                                              ,t3
                                              ,t4
                                              ,t5
                                              )
                         VALUES (p_document.edi_id
                                ,p_goods_edi_id
                                ,p_oht_kaup_id
                                ,NULL
                                ,NULL
                                ,'AAD'
                                ,remove_line_break (substr (p_document.goods (i).danger_name
                                                           ,1
                                                           ,350))
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                );
                END IF;

                -- package
                FOR j IN 1 .. p_document.goods (i).package.count
                LOOP
                    l_step :=
                        'FOR p_document.goods '
                        || i
                        || ' and package '
                        || j;

                    INSERT INTO edifact.pakend (kaup_id
                                               ,pakendi_tyyp
                                               ,kohtade_arv
                                               ,kirjeldus
                                               ,kihi_number
                                               ,konsolideeritud_kohtade_arv
                                               ,element_index
                                               ,positsioon
                                               )
                         VALUES (p_goods_edi_id
                                ,p_document.goods (i).package (j).code
                                ,p_document.goods (i).package (j).amount
                                ,remove_line_break (p_document.goods (i).package (j).description)
                                ,p_document.goods (i).package (j).layer
                                ,p_document.goods (i).package (j).larged_packets_amount
                                ,p_document.goods (i).package (j).element_index
                                ,p_document.goods (i).package (j).positsioon
                                );
                END LOOP;

                --labels
                FOR j IN 1 .. p_document.goods (i).label.count
                LOOP
                    l_step :=
                        'FOR p_document.goods '
                        || i
                        || ' and label '
                        || j;

                    INSERT INTO edifact.markeering (kaup_id
                                                   , --KELLE_POOLT,
                                                    markeering
                                                   )
                         VALUES (p_goods_edi_id
                                ,substr (p_document.goods (i).label (j).label
                                        ,1
                                        ,35)
                                );
                END LOOP;

                -- texts AAA
                l_step   :=
                    'FOR p_document.goods '
                    || i
                    || ' and texts AAA';

                FOR j IN 1 .. p_document.goods (i).description_text.count
                LOOP
                    split_text_into_db (in_smgs => p_document
                                       ,in_text => p_document.goods (i).description_text (j).text
                                       ,in_case => 'GOODS.DESCRIPTION'
                                       ,in_role => 'AAA'
                                       ,in_id   => p_goods_edi_id);
                END LOOP;

                -- texts PRD, ABJ, AAZ
                IF     p_document.goods (i).name_comment IS NOT NULL
                   AND p_document.goods (i).name_comment.count > 0
                THEN
                    FOR c IN 1 .. p_document.goods (i).name_comment.count
                    LOOP
                        split_text_into_db (in_smgs => p_document
                                           ,in_text => p_document.goods (i).name_comment (c).text
                                           ,in_case => 'GOODS.DESCRIPTION'
                                           ,in_role => nvl (p_document.goods (i).name_comment (c).smgs_role, 'PRD')
                                           ,in_id   => p_goods_edi_id);
                    END LOOP;
                END IF;

                --Dangerous Goods Stamps
                IF p_document.goods (i).dangerous_goods_stamps.count>0 THEN
                FOR j IN 1 .. p_document.goods (i).dangerous_goods_stamps.count
                LOOP
                    INSERT INTO edifact.tekst (sonum_id
                                              ,kaup_id
                                              ,oht_kaup_id
                                              ,toll_id
                                              ,seadmed_id
                                              ,tunnus
                                              ,tekst
                                              ,t1
                                              ,t2
                                              ,t3
                                              ,t4
                                              ,t5
                                              )
                         VALUES (p_document.edi_id
                                ,p_goods_edi_id
                                ,p_oht_kaup_id
                                ,NULL
                                ,NULL
                                ,'AAC'
                                ,remove_line_break (substr (p_document.goods (i).dangerous_goods_stamps (j).label
                                                           ,1
                                                           ,350))
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                );
                END LOOP;
                END IF;
            END LOOP;
        END IF;

        -- create RQR text
        l_step                 := 'create RQR text';
        z_rqr_text             := create_rqr (p_document);

        l_step                 := 'create RQR text and INSERT INTO edifact.tekst';

        INSERT INTO edifact.tekst (sonum_id
                                  ,kaup_id
                                  ,oht_kaup_id
                                  ,toll_id
                                  ,seadmed_id
                                  ,tunnus
                                  ,tekst
                                  ,t1
                                  ,t2
                                  ,t3
                                  ,t4
                                  ,t5
                                  )
             VALUES (p_document.edi_id
                    ,NULL
                    ,NULL
                    ,NULL
                    ,NULL
                    ,'RQR'
                    ,substr (z_rqr_text
                            ,1
                            ,350)
                    ,NULL
                    ,NULL
                    ,NULL
                    ,NULL
                    ,NULL
                    );

        --documents
        IF p_document.document.count > 0
        THEN
            FOR i IN 1 .. p_document.document.count
            LOOP
                l_step :=
                    'FOR p_document.document '
                    || i;

                INSERT INTO edifact.dokument (sonum_id
                                             ,toll_id
                                             ,dokum_kood
                                             ,dokum_nr
                                             ,dokum_nimetus
                                             ,dokum_liik
                                             ,dokum_kuupaev
                                             ,radm_lyhinimi
                                             ,eksemplaride_arv
                                             )
                     VALUES (p_document.edi_id
                            ,NULL
                            ,p_document.document (i).code
                            ,CASE
                                 WHEN p_document.document (i).doc_count IS NULL
                                 THEN
                                     substr (trim (p_document.document (i).docnumber)
                                            ,nvl (length (trim (p_document.document (i).doc_name)), 0) + 1
                                            ,35)
                                 ELSE
                                     substr (p_document.document (i).docnumber
                                            ,1
                                            ,35)
                             END
                            ,p_document.document (i).doc_name
                            ,p_document.document (i).doc_type
                            ,p_document.document (i).created_at
                            ,p_document.document (i).rw_admin
                            ,p_document.document (i).doc_count
                            );
            END LOOP;
        END IF;

        --texts
        IF p_document.text.count > 0
        THEN
            FOR i IN 1 .. p_document.text.count
            LOOP
                IF     p_document.text (i).smgs_role = 'IRP'
                   AND p_document.text (i).code IS NOT NULL
                THEN
                    l_step :=
                        'FOR p_document.text '
                        || i
                        || ' and smgs_role = IRP';

                    INSERT INTO edifact.tekst (sonum_id
                                              ,kaup_id
                                              ,oht_kaup_id
                                              ,toll_id
                                              ,seadmed_id
                                              ,tunnus
                                              ,tekst
                                              ,tekst_koodina
                                              ,t1
                                              ,t2
                                              ,t3
                                              ,t4
                                              ,t5
                                              )
                         VALUES (p_document.edi_id
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                ,p_document.text (i).smgs_role
                                ,remove_line_break (substr (p_document.text (i).text
                                                           ,1
                                                           ,350))
                                ,substr (p_document.text (i).code
                                        ,1
                                        ,2)
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                );
                ELSIF     p_document.text (i).smgs_role IN ('AAO'
                                                           ,'ICN'
                                                           ,'DCL'
                                                           ,'AAH'
                                                           ,'BLR'
                                                           ,'AEA'
                                                           ,'TRA')
                      AND p_document.text (i).text IS NOT NULL
                THEN
                    l_step :=
                        'FOR p_document.text '
                        || i
                        || ' and smgs_role IN AAO,ICN,DCL,AAH..';

                    INSERT INTO edifact.tekst (sonum_id
                                              ,kaup_id
                                              ,oht_kaup_id
                                              ,toll_id
                                              ,seadmed_id
                                              ,tunnus
                                              ,tekst
                                              ,t1
                                              ,t2
                                              ,t3
                                              ,t4
                                              ,t5
                                              )
                         VALUES (p_document.edi_id
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                ,CASE WHEN p_document.text (i).smgs_role = 'AAO' THEN 'ICN' ELSE p_document.text (i).smgs_role END
                                ,remove_line_break (substr (p_document.text (i).text
                                                           ,1
                                                           ,350))
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                );
                ELSIF     p_document.text (i).smgs_role IN ('HAN')
                      AND p_document.text (i).code = 'ZPL'
                THEN
                    l_step :=
                        'FOR p_document.text '
                        || i
                        || ' and smgs_role IN HAN..';

                    INSERT INTO edifact.tekst (sonum_id
                                              ,kaup_id
                                              ,oht_kaup_id
                                              ,toll_id
                                              ,seadmed_id
                                              ,tunnus
                                              ,tekst
                                              ,tekst_koodina
                                              ,t1
                                              ,t2
                                              ,t3
                                              ,t4
                                              ,t5
                                              )
                         VALUES (p_document.edi_id
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                ,p_document.text (i).smgs_role
                                ,p_document.text (i).code
                                ,p_document.text (i).code
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                ,NULL
                                );
                END IF;
            END LOOP;
        END IF;

        /* Added by ale_x @ 06.10.2016 */
        /* Purpose: Save reference to original SMGS (for redispatch-SMGS) */
        IF     smgs.transportationstatus.is_reforwarding = 1
           AND smgs.transportationstatus.originalsmgs_edi_id IS NOT NULL
           AND smgs.transportationstatus.originalsmgsnumber IS NOT NULL
        THEN
            l_step := 'Save reference to original SMGS and INSERT INTO edifact.viide';

            INSERT INTO edifact.viide (sonum_id
                                      ,tunnus
                                      ,viitenumber
                                      ,parent_name
                                      ,parent_id
                                      )
                 VALUES (p_document.edi_id
                        ,'AAM'
                        ,smgs.transportationstatus.originalsmgsnumber
                        ,'SONUM'
                        ,smgs.transportationstatus.originalsmgs_edi_id
                        );

            l_step := 'Save reference to original SMGS and INSERT INTO edifact.tekst';

            INSERT INTO edifact.tekst (sonum_id
                                      ,tunnus
                                      ,tekst
                                      ,tekst_koodina
                                      ,t1
                                      )
                 VALUES (p_document.edi_id
                        ,'CHG'
                        ,NULL
                        ,'113'
                        ,NULL
                        );
        END IF;

        /* End of "Added by ale_x @ 06.10.2016" */
        l_step                 := 'INSERT INTO edifact.logi';

        INSERT INTO edifact.logi (ymbrik_id
                                 ,in_out
                                 ,staatus
                                 )
             VALUES (p_ymbrik_id
                    ,'OUT'
                    ,edifact.fm.c_valmis_saatmiseks
                    );

        COMMIT;

        l_step                 := 'korrastab tabelis SONUM valjade EELMISTE_ARV ja MUUTMISTE_ARV vaartused';

        BEGIN
            -- Tiit V. offer: korrastab tabelis SONUM valjade EELMISTE_ARV ja MUUTMISTE_ARV vaartused
            edifact.set_iftmin_history (p_document.smgs_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.save_document - set_iftmin_history'
                                                ,p_params => l_params);
        END;

        -- check if application item "MODE" exists in current APEX application while executed from APEX
        l_step                 := 'check if application item "MODE" exists in current APEX application while executed from APEX';

        SELECT count (0)
          INTO z_count
          FROM apex_application_items
         WHERE     application_id = v ('APP_ID')
               AND item_name = 'MODE';

        -- set current mode to VIEW
        l_step                 := 'set current mode to VIEW';

        IF     v ('APP_USER') IS NOT NULL
           AND z_count > 0
        THEN
            apex_util.set_session_state ('MODE'
                                        ,'VIEW');
            apex_util.set_session_state ('P4_SOURCE'
                                        ,'EDIFACT');
            apex_util.set_session_state ('P4_SONUM_ID'
                                        ,p_document.edi_id);
            apex_util.set_session_state ('P34_SOURCE'
                                        ,'EDIFACT');
            apex_util.set_session_state ('P34_SONUM_ID'
                                        ,p_document.edi_id);

            IF v ('MODE') = 'CREATE'
            THEN
                add_message (p_message        => get_tekst (6301)
                            ,p_realm          => 'info'
                            ,p_www_tekstid_id => 6301);
            ELSE
                add_message (p_message        => get_tekst (6300)
                            ,p_realm          => 'info'
                            ,p_www_tekstid_id => 6300);
                p_message := message;
                RETURN;
            END IF;
        END IF;

        p_message              := message;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            add_message (p_message => $$plsql_unit
                                     || '.save_document:'
                                     || dbms_utility.format_error_stack
                                     || ', '
                                     || dbms_utility.format_error_backtrace
                        ,p_realm   => 'error'
                        ,p_code    => sqlcode);
            l_params          := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.save_document'
                                            ,p_params => l_params);
            p_message         := message;
            l_params          := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.append_param (l_params
                                               ,'p_message.COUNT'
                                               ,p_message.count);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.save_document with p_message.COUNT'
                                            ,p_params => l_params);
            p_document.edi_id := NULL;
    END save_document;

    FUNCTION xml_to_var (p_xml          IN XMLTYPE
                        ,p_carrier_code IN VARCHAR2)
        RETURN spv.smgs2_interface.t_smgs
    IS
        p_smgs                spv.smgs2_interface.t_smgs;
        z_participant_role    apex_application_global.vc_arr2 := apex_util.string_to_table ('receiver:sender:undertaker:payer:payerAtDispatch:payerAtDestination');
        z_station_role        apex_application_global.vc_arr2 := apex_util.string_to_table ('stationDeparture:stationDestination:stationBorder');

        z_participant_path    VARCHAR2 (128);
        z_sender_edoc         VARCHAR2 (3);
        z_index               PLS_INTEGER;
        z_wag_idx             PLS_INTEGER;
        z_cont_idx            PLS_INTEGER;
        z_lead_idx            PLS_INTEGER;
        l_equip_idx           PLS_INTEGER;
        l_goods_idx           PLS_INTEGER;
        l_idx                 PLS_INTEGER;

        l_tekst               VARCHAR2 (4000);
        l_params              logger_service.logger.tab_param;
        l_step                VARCHAR2 (300);
        l_text_clob           CLOB;
        l_text_clob_do        VARCHAR2 (1);
        l_text_role           VARCHAR2 (3);
        l_clob_offset         INTEGER;
        l_clob_length         INTEGER;
        l_text_cnt            PLS_INTEGER;
        l_text_max_length_dcl PLS_INTEGER;

        FUNCTION check_versionnumber (z_version IN VARCHAR2)
            RETURN BOOLEAN
        IS
        BEGIN
            IF    z_version IS NULL
               OR z_version IN ('2015.1.1')
            THEN
                RETURN TRUE;
            END IF;

            RETURN FALSE;
        END;
    BEGIN
        l_step             := 'begin';
        p_smgs.data_source := 'XML';
        p_smgs.text        := spv.smgs2_interface.tb_edi_text ();
        p_smgs.participant := spv.smgs2_interface.tb_edi_participant ();
        p_smgs.station     := spv.smgs2_interface.tb_edi_station ();
        p_smgs.goods       := spv.smgs2_interface.tb_edi_goods ();
        p_smgs.wagon       := spv.smgs2_interface.tb_edi_wagon ();
        p_smgs.document    := spv.smgs2_interface.tb_edi_document ();
        p_smgs.border      := spv.smgs2_interface.tb_border ();
        p_smgs.tempel      := spv.smgs2_interface.tb_edi_tempel ();

        /* common parameters */
        l_step             := 'common parameters';

        FOR param IN (SELECT substr (extractvalue (a.x
                                                  ,'/message/waybill/@number')
                                    ,1
                                    ,12)                                                                sn_number
                            ,extractvalue (a.x
                                          ,'/message/waybill/@messageType')                             messagetype
                            ,to_number (extractvalue (a.x
                                                     ,'/message/waybill/@messageFunction'))             messagefunction
                            ,to_number (extractvalue (a.x
                                                     ,'/message/waybill/@sendingType'))                 sendingtype
                            ,extractvalue (a.x
                                          ,'/message/waybill/@sendingDate')                             sendingdate
                            ,extractvalue (a.x
                                          ,'/message/waybill/@loadedBy')                                loadedby
                            ,extractvalue (a.x
                                          ,'/message/waybill/invoiceTotalCost')                         invoicetotalcost
                            ,extractvalue (a.x
                                          ,'/message/waybill/invoiceTotalCost/@invoiceCurrencyCode')    invoicecurrencycode
                            ,extractvalue (a.x
                                          ,'/message/waybill/@paperFree')                               paperfree
                            ,extractvalue (a.x
                                          ,'/message/waybill/@weightDetermined')                        weightdetermined
                            ,extractvalue (a.x
                                          ,'/message/@versionNumber')                                   versionnumber
                        FROM (SELECT p_xml x FROM dual) a)
        LOOP
            p_smgs.smgs_number              := param.sn_number;
            p_smgs.dokum_kood               := param.messagetype;
            p_smgs.saad_funk_kood           := param.messagefunction;
            p_smgs.smgs_type                := param.sendingtype;
            p_smgs.created_at               :=
                to_date (param.sendingdate
                        ,'dd.mm.yyyy');
            p_smgs.who_loaded               := param.loadedby;
            p_smgs.carrier_code4            := p_carrier_code;

            IF NOT check_versionnumber (param.versionnumber)
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.append_param (l_params
                                                   ,'Unknown IFTMIN version number'
                                                   ,param.versionnumber);
                logger_service.logger.log_info (p_text   => 'Unknown IFTMIN version number'
                                               ,p_scope  => 'spv.'
                                                           || $$plsql_unit
                                                           || '.xml_to_var - common parameters'
                                               ,p_params => l_params);
            END IF;

            /* Способ определения массы */
            p_smgs.text.extend;
            z_index                         := p_smgs.text.count;
            p_smgs.text (z_index).smgs_role := 'IRP';
            -- NB! This attribute is currently expected to be a 'text.code' in the xml output and not text.text!
            -- Also the EDIFACT segment 'FTX+IRP++CODE+TEXT' contains 2(!) values total, the code AND the text, but only one is parsed from XML input.
            p_smgs.text (z_index).text      := param.weightdetermined;
            p_smgs.text (z_index).code      :=
                substr (param.weightdetermined
                       ,1
                       ,2);

            /* Признак безбумажной технологии */
            IF param.paperfree = '1'
            THEN
                z_sender_edoc                   := 'JAH';
                -- Emulate edifact
                p_smgs.text.extend;
                z_index                         := z_index + 1;
                p_smgs.text (z_index).smgs_role := 'HAN';
                p_smgs.text (z_index).code      := 'ZPL';
            END IF;

            EXIT;
        END LOOP;

        IF p_smgs.smgs_number IS NULL
        THEN
            raise_application_error (-20000
                                    ,'Saadetise number is null!');
        END IF;

        /* Added by ale_x @ 06.10.2016 */
        /* transportation status ("DOSYLKA") */
        l_step             := 'transportation status ("DOSYLKA")';

        BEGIN
            p_smgs.transportationstatus.is_reforwarding := 0;

            FOR i IN (SELECT substrb (extractvalue (value (a)
                                                   ,'/transportationStatus/@originalSMGSNumber')
                                     ,1
                                     ,10)    originalsmgsnumber
                            ,substrb (extractvalue (value (a)
                                                   ,'/transportationStatus')
                                     ,1
                                     ,10)    is_reforwarding
                        FROM TABLE (xmlsequence (p_xml.extract ('/message/waybill/transportationStatus'))) a)
            LOOP
                l_step :=
                    'transportation status ("DOSYLKA") and originalsmgsnumber '
                    || i.originalsmgsnumber;

                IF upper (i.is_reforwarding) IN ('TRUE'
                                                ,'1')
                THEN
                    p_smgs.transportationstatus.is_reforwarding     := 1;
                    p_smgs.transportationstatus.originalsmgsnumber  := trim (i.originalsmgsnumber);
                    p_smgs.transportationstatus.originalsmgs_edi_id := edifact.get_edi_id_by_smgs_number (smgs.transportationstatus.originalsmgsnumber);
                    debug_message ('Found redispatching! OriginalSMGSNumber: '
                                   || p_smgs.transportationstatus.originalsmgsnumber);
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.xml_to_var - transportation status ("DOSYLKA")'
                                                ,p_params => l_params);
        END;

        /* End of "Added by ale_x @ 06.10.2016" */

        /* participant */
        FOR i IN 1 .. z_participant_role.count
        LOOP
            l_step :=
                'FOR z_participant_role '
                || i
                || ' and undertaker';

            IF z_participant_role (i) = 'undertaker'
            THEN
                z_participant_path :=
                    z_participant_role (i)
                    || '/undertakerData';
            ELSE
                z_participant_path := z_participant_role (i);
            END IF;

            l_step :=
                'FOR z_participant_role '
                || i
                || ' and participant';

            FOR participant IN (SELECT decode (z_participant_role (i)
                                              ,'receiver', 'CN'
                                              ,'sender', 'CZ'
                                              ,'payer', 'GS'
                                              ,'payerAtDispatch', 'DCP'
                                              ,'payerAtDestination', 'CPD'
                                              ,'undertaker', 'CA')                 smgs_role
                                      ,substr (extractvalue (value (a)
                                                            ,'/'
                                                             || z_participant_path
                                                             || '/name')
                                              ,1
                                              ,175)                                name
                                      ,substrb (extractvalue (value (a)
                                                             ,'/'
                                                              || z_participant_path
                                                              || '/jobTitle')
                                               ,1
                                               ,256)                               jobtitle
                                      ,substrb (extractvalue (value (a)
                                                             ,'/'
                                                              || z_participant_path
                                                              || '/signature')
                                               ,1
                                               ,256)                               signature
                                      ,substr (extractvalue (value (a)
                                                            ,'/'
                                                             || z_participant_path
                                                             || '/address/@state')
                                              ,1
                                              ,9)                                  state
                                      ,substr (extractvalue (value (a)
                                                            ,'/'
                                                             || z_participant_path
                                                             || '/address/@city')
                                              ,1
                                              ,35)                                 city
                                      ,substr (extractvalue (value (a)
                                                            ,'/'
                                                             || z_participant_path
                                                             || '/address/@street')
                                              ,1
                                              ,140)                                street
                                      ,substr (extractvalue (value (a)
                                                            ,'/'
                                                             || z_participant_path
                                                             || '/address/@zipcode')
                                              ,1
                                              ,9)                                  zipcode
                                      ,substr (extractvalue (value (a)
                                                            ,'/'
                                                             || z_participant_path
                                                             || '/address/@telefon')
                                              ,1
                                              ,512)                                telefon
                                      ,substr (extractvalue (value (a)
                                                            ,'/'
                                                             || z_participant_path
                                                             || '/address/@fax')
                                              ,1
                                              ,512)                                fax
                                      ,substr (extractvalue (value (a)
                                                            ,'/'
                                                             || z_participant_path
                                                             || '/address/@email')
                                              ,1
                                              ,512)                                email
                                      ,extract (value (a)
                                               ,'/'
                                                || z_participant_path)             participant_xml
                                      , /* payer to undertaker reference*/
                                       extractvalue (value (a)
                                                    ,'/'
                                                     || z_participant_path
                                                     || '/@undertakerCode')        undertakercode
                                      , /* undertaker regions */
                                       extractvalue (value (a)
                                                    ,'/'
                                                     || z_participant_role (i)
                                                     || '/stationFrom/name')       f_station_name
                                      ,extractvalue (value (a)
                                                    ,'/'
                                                     || z_participant_role (i)
                                                     || '/stationFrom/@code')      f_station_code
                                      ,extractvalue (value (a)
                                                    ,'/'
                                                     || z_participant_role (i)
                                                     || '/stationFrom/rwAdmin')    f_station_rwadmin
                                      ,extractvalue (value (a)
                                                    ,'/'
                                                     || z_participant_role (i)
                                                     || '/stationFrom/state')      f_station_state
                                      ,extractvalue (value (a)
                                                    ,'/'
                                                     || z_participant_role (i)
                                                     || '/stationTo/name')         l_station_name
                                      ,extractvalue (value (a)
                                                    ,'/'
                                                     || z_participant_role (i)
                                                     || '/stationTo/@code')        l_station_code
                                      ,extractvalue (value (a)
                                                    ,'/'
                                                     || z_participant_role (i)
                                                     || '/stationTo/rwAdmin')      l_station_rwadmin
                                      ,extractvalue (value (a)
                                                    ,'/'
                                                     || z_participant_role (i)
                                                     || '/stationTo/state')        l_station_state
                                  FROM TABLE (xmlsequence (p_xml.extract ('/message/waybill/'
                                                                          || z_participant_role (i)))) a)
            LOOP
                l_step   :=
                    'FOR z_participant_role '
                    || i
                    || ' and participant.name '
                    || participant.name;
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.append_param (l_params
                                                   ,'participant.smgs_role'
                                                   ,participant.smgs_role);
                logger_service.logger.append_param (l_params
                                                   ,'participant.name'
                                                   ,participant.name);
                logger_service.logger.log_info (p_text   => 'z_participant_role '
                                                           || i
                                               ,p_scope  => 'spv.'
                                                           || $$plsql_unit
                                                           || '.xml_to_var - z_participant_role'
                                               ,p_params => l_params);

                IF participant.name IS NOT NULL
                THEN
                    p_smgs.participant.extend;
                    p_smgs.participant (p_smgs.participant.count).smgs_role      := participant.smgs_role;
                    p_smgs.participant (p_smgs.participant.count).name           := participant.name;

                    p_smgs.participant (p_smgs.participant.count).signature      := participant.signature;
                    p_smgs.participant (p_smgs.participant.count).state          := participant.state;
                    p_smgs.participant (p_smgs.participant.count).city           := participant.city;
                    p_smgs.participant (p_smgs.participant.count).street         := participant.street;
                    p_smgs.participant (p_smgs.participant.count).zipcode        := participant.zipcode;
                    p_smgs.participant (p_smgs.participant.count).telefon        := participant.telefon;
                    p_smgs.participant (p_smgs.participant.count).fax            := participant.fax;
                    p_smgs.participant (p_smgs.participant.count).email          := participant.email;
                    p_smgs.participant (p_smgs.participant.count).participant_id := sys_guid;

                    /* participant codes*/
                    l_step                                                       :=
                        'FOR z_participant_role '
                        || i
                        || ' and participant_id '
                        || p_smgs.participant (p_smgs.participant.count).participant_id;
                    p_smgs.participant (p_smgs.participant.count).codes          := spv.smgs2_interface.td_edi_participant_code ();

                    FOR c_codes IN (SELECT extractvalue (value (a)
                                                        ,'/code')          code_value
                                          ,extractvalue (value (a)
                                                        ,'/code/@type')    code_type
                                      FROM TABLE (xmlsequence (participant.participant_xml
                                                                 .extract (
                                                                   '/'
                                                                   || decode (z_participant_role (i), 'undertaker', 'undertakerData', z_participant_role (i))
                                                                   || '/code'
                                                               ))) a)
                    LOOP
                        l_step :=
                            'FOR z_participant_role '
                            || i
                            || ' and participant_id '
                            || p_smgs.participant (p_smgs.participant.count).participant_id
                            || 'and c_codes.code_value '
                            || c_codes.code_value;

                        p_smgs.participant (p_smgs.participant.count).codes.extend;
                        p_smgs.participant (p_smgs.participant.count).codes (p_smgs.participant (p_smgs.participant.count).codes.count).code_type :=
                            c_codes.code_type;
                        p_smgs.participant (p_smgs.participant.count).codes (p_smgs.participant (p_smgs.participant.count).codes.count).code_value :=
                            c_codes.code_value;

                        IF c_codes.code_type = 'ZEE'
                        THEN
                            /* Eesti rigi kood*/
                            p_smgs.participant (p_smgs.participant.count).reg_code := c_codes.code_value;
                        ELSE
                            /* double TGNL code into client code4 */
                            IF c_codes.code_type = 'Z01'
                            THEN
                                IF length (c_codes.code_value) > 4
                                THEN
                                    raise_application_error (-20000
                                                            ,'Invalid Z01 code format for participant "'
                                                             || p_smgs.participant (p_smgs.participant.count).name
                                                             || '"');
                                END IF;

                                p_smgs.participant (p_smgs.participant.count).code4 := c_codes.code_value;
                            END IF;
                        END IF;
                    END LOOP;

                    IF     participant.jobtitle IS NOT NULL
                       AND z_participant_role (i) = 'sender'
                    THEN
                        set_participant_code (p_smgs.participant (p_smgs.participant.count)
                                             ,nvl (edifact.get_sonumivahetuse_parameeter ('IFTMIN_PN_SENDER_JOBTITLE_CODE'), 'ZZZ')
                                             ,participant.jobtitle);
                    END IF;

                    /* for sender E-Document */
                    l_step                                                       :=
                        'FOR z_participant_role '
                        || i
                        || ' and participant_id '
                        || p_smgs.participant (p_smgs.participant.count).participant_id
                        || 'and for sender E-Document';

                    IF z_participant_role (i) = 'sender'
                    THEN
                        p_smgs.participant (p_smgs.participant.count).e_document := z_sender_edoc;
                    END IF;

                    /* for undertaker - define regions */
                    IF z_participant_role (i) = 'undertaker'
                    THEN
                        l_step                                                                    :=
                            'FOR z_participant_role '
                            || i
                            || ' and participant_id '
                            || p_smgs.participant (p_smgs.participant.count).participant_id
                            || 'and for undertaker - define regions 1';
                        p_smgs.participant (p_smgs.participant.count).carrier_region              := spv.smgs2_interface.tb_edi_station ();
                        p_smgs.participant (p_smgs.participant.count).carrier_region.extend;
                        p_smgs.participant (p_smgs.participant.count).carrier_region (1).code6    := participant.f_station_code;
                        p_smgs.participant (p_smgs.participant.count).carrier_region (1).name     := participant.f_station_name;
                        p_smgs.participant (p_smgs.participant.count).carrier_region (1).state    := participant.f_station_state;
                        p_smgs.participant (p_smgs.participant.count).carrier_region (1).rw_admin := participant.f_station_rwadmin;
                        correct_station_data (p_smgs.participant (p_smgs.participant.count).carrier_region (1));

                        l_step                                                                    :=
                            'FOR z_participant_role '
                            || i
                            || ' and participant_id '
                            || p_smgs.participant (p_smgs.participant.count).participant_id
                            || 'and for undertaker - define regions 2';
                        p_smgs.participant (p_smgs.participant.count).carrier_region.extend;
                        p_smgs.participant (p_smgs.participant.count).carrier_region (2).code6    := participant.l_station_code;
                        p_smgs.participant (p_smgs.participant.count).carrier_region (2).name     := participant.l_station_name;
                        p_smgs.participant (p_smgs.participant.count).carrier_region (2).state    := participant.l_station_state;
                        p_smgs.participant (p_smgs.participant.count).carrier_region (2).rw_admin := participant.l_station_rwadmin;
                        correct_station_data (p_smgs.participant (p_smgs.participant.count).carrier_region (2));

                        l_step                                                                    :=
                            'FOR z_participant_role '
                            || i
                            || ' and participant_id '
                            || p_smgs.participant (p_smgs.participant.count).participant_id
                            || 'and for undertaker - define regions - state IS NULL';

                        IF p_smgs.participant (p_smgs.participant.count).state IS NULL
                        THEN
                            p_smgs.participant (p_smgs.participant.count).state :=
                                get_undertaker_state (get_participant_code (p_smgs.participant (p_smgs.participant.count)
                                                                           ,'Z13'));
                        END IF;
                    END IF;

                    p_smgs.participant (p_smgs.participant.count).documents      := spv.smgs2_interface.tb_edi_document ();

                    /* for expeditors */
                    l_step                                                       :=
                        'FOR z_participant_role '
                        || i
                        || ' and participant_id '
                        || p_smgs.participant (p_smgs.participant.count).participant_id
                        || 'and for expeditors';

                    IF z_participant_role (i) = 'payer'
                    THEN
                        p_smgs.participant (p_smgs.participant.count).parent_participant_code := participant.undertakercode;

                        /* search for parent participant */
                        FOR undertaker IN (SELECT extractvalue (value (a)
                                                               ,'/undertaker/undertakerData/name')    undertaker_name
                                                 ,extractvalue (value (a)
                                                               ,'/undertaker/undertakerData/code')    undertaker_code
                                             FROM TABLE (xmlsequence (p_xml.extract ('/message/waybill/undertaker'))) a
                                            WHERE     extractvalue (value (a)
                                                                   ,'/undertaker/undertakerData/code/@type') = 'Z13'
                                                  AND extractvalue (value (a)
                                                                   ,'/undertaker/undertakerData/code') = participant.undertakercode)
                        LOOP
                            /* search undertaker id in p_smgs */
                            FOR j IN 1 .. p_smgs.participant.count
                            LOOP
                                IF p_smgs.participant (j).name = undertaker.undertaker_name
                                THEN
                                    p_smgs.participant (p_smgs.participant.count).parent_participant_id := p_smgs.participant (j).participant_id;
                                END IF;
                            END LOOP;
                        END LOOP;
                    END IF;
                END IF;
            END LOOP;
        END LOOP;

        /* stations */
        l_step             := 'stations';
        z_index            := 1;

        FOR i IN 1 .. z_station_role.count
        LOOP
            FOR station IN (SELECT substr (extractvalue (a.x
                                                        ,'/message/waybill/'
                                                         || z_station_role (i)
                                                         || '/@code')
                                          ,1
                                          ,6)      code
                                  ,substr (extractvalue (a.x
                                                        ,'/message/waybill/'
                                                         || z_station_role (i)
                                                         || '/name')
                                          ,1
                                          ,128)    name
                                  ,CASE
                                       WHEN z_station_role (i) = 'stationDeparture' THEN '5'
                                       WHEN z_station_role (i) = 'stationDestination' THEN '8'
                                       WHEN z_station_role (i) = 'stationBorder' THEN '17'
                                   END             smgs_role
                                  ,substr (extractvalue (a.x
                                                        ,'/message/waybill/'
                                                         || z_station_role (i)
                                                         || '/state')
                                          ,1
                                          ,2)      state
                                  ,substr (extractvalue (a.x
                                                        ,'/message/waybill/'
                                                         || z_station_role (i)
                                                         || '/rwAdmin')
                                          ,1
                                          ,2)      rw_admin
                              FROM (SELECT p_xml x FROM dual) a
                             WHERE extractvalue (a.x
                                                ,'/message/waybill/'
                                                 || z_station_role (i)
                                                 || '/@code')
                                       IS NOT NULL)
            LOOP
                l_step                                          :=
                    'FOR z_station_role '
                    || i
                    || ' and position '
                    || z_index;
                p_smgs.station.extend;
                p_smgs.station (p_smgs.station.count).code6     := station.code;
                p_smgs.station (p_smgs.station.count).name      := station.name;
                p_smgs.station (p_smgs.station.count).smgs_role := station.smgs_role;
                p_smgs.station (p_smgs.station.count).state     := station.state;
                p_smgs.station (p_smgs.station.count).rw_admin  := station.rw_admin;
                p_smgs.station (p_smgs.station.count).position  := z_index;
                z_index                                         := z_index + 1;
                correct_station_data (p_smgs.station (p_smgs.station.count));
            END LOOP;
        END LOOP;

        --stationTransitBorderOut
        l_step             := 'stationTransitBorderOut';

        FOR station IN (SELECT extractvalue (value (t)
                                            ,'/stationTransitBorderOut/@code')      code
                              ,'42'                                                 smgs_role
                              ,extractvalue (value (t)
                                            ,'/stationTransitBorderOut/state')      state
                              ,extractvalue (value (t)
                                            ,'/stationTransitBorderOut/name')       name
                              ,extractvalue (value (t)
                                            ,'/stationTransitBorderOut/rwAdmin')    rw_admin
                          FROM (SELECT p_xml x FROM dual) a
                              ,TABLE (xmlsequence (p_xml.extract ('/message/waybill/stationTransitBorderOut')))  t)
        LOOP
            l_step                                         :=
                'stationTransitBorderOut FOR station with position '
                || z_index;
            p_smgs.station.extend;
            p_smgs.station (p_smgs.station.count).code6    :=
                substr (station.code
                       ,1
                       ,6);
            p_smgs.station (p_smgs.station.count).name     :=
                substr (station.name
                       ,1
                       ,128);
            p_smgs.station (p_smgs.station.count).smgs_role :=
                substr (station.smgs_role
                       ,1
                       ,3);
            p_smgs.station (p_smgs.station.count).state    :=
                substr (station.state
                       ,1
                       ,2);
            p_smgs.station (p_smgs.station.count).rw_admin :=
                substr (station.rw_admin
                       ,1
                       ,2);
            p_smgs.station (p_smgs.station.count).position := z_index;
            z_index                                        := z_index + 1;
            correct_station_data (p_smgs.station (p_smgs.station.count));
        END LOOP;

        --stationTransitBorderIn
        l_step             := 'stationTransitBorderIn';

        FOR station IN (SELECT extractvalue (value (t)
                                            ,'/stationTransitBorderIn/@code')      code
                              ,'41'                                                smgs_role
                              ,extractvalue (value (t)
                                            ,'/stationTransitBorderIn/state')      state
                              ,extractvalue (value (t)
                                            ,'/stationTransitBorderIn/name')       name
                              ,extractvalue (value (t)
                                            ,'/stationTransitBorderIn/rwAdmin')    rw_admin
                          FROM (SELECT p_xml x FROM dual) a
                              ,TABLE (xmlsequence (p_xml.extract ('/message/waybill/stationTransitBorderIn')))  t)
        LOOP
            l_step                                         :=
                'stationTransitBorderIn FOR station with position '
                || z_index;
            p_smgs.station.extend;
            p_smgs.station (p_smgs.station.count).code6    :=
                substr (station.code
                       ,1
                       ,6);
            p_smgs.station (p_smgs.station.count).name     :=
                substr (station.name
                       ,1
                       ,128);
            p_smgs.station (p_smgs.station.count).smgs_role :=
                substr (station.smgs_role
                       ,1
                       ,3);
            p_smgs.station (p_smgs.station.count).state    :=
                substr (station.state
                       ,1
                       ,2);
            p_smgs.station (p_smgs.station.count).rw_admin :=
                substr (station.rw_admin
                       ,1
                       ,2);
            p_smgs.station (p_smgs.station.count).position := z_index;
            z_index                                        := z_index + 1;
            correct_station_data (p_smgs.station (p_smgs.station.count));
        END LOOP;

        /* goods */
        l_step             := 'goods';

        FOR c_goods IN (SELECT substrb (extractvalue (value (a)
                                                     ,'/goods/@etsngCode')
                                       ,1
                                       ,6)                                                etsngcode
                              ,substrb (extractvalue (value (a)
                                                     ,'/goods/@gngCode')
                                       ,1
                                       ,12)                                               gngcode
                              ,to_number (extractvalue (value (a)
                                                       ,'/goods/@position'))              position
                              ,extractvalue (value (a)
                                            ,'/goods/@stateDispatch')                     statedispatch
                              ,extractvalue (value (a)
                                            ,'/goods/@stateDestination')                  statedestination
                              -- there CAN be more than one description, get the first value by default
                              ,substr (extractvalue (value (a)
                                                    ,'/goods/description[1]')
                                      ,1
                                      ,350)                                               description
                              ,substr (extractvalue (value (a)
                                                    ,'/goods/dangerGoods')
                                      ,1
                                      ,350)                                               dangergoods
                              ,substr (extractvalue (value (a)
                                                    ,'/goods/dangerGoods/@code')
                                      ,1
                                      ,7)                                                 dangergoodscode
                              ,substr (extractvalue (value (a)
                                                    ,'/goods/dangerGoods/@emergencyCardCode')
                                      ,1
                                      ,7)                                                 emergencycardcode
                              ,substr (extractvalue (value (a)
                                                    ,'/goods/dangerGoods/@class')
                                      ,1
                                      ,35)                                                dangergoodsclass
                              ,substr (extractvalue (value (a)
                                                    ,'/goods/dangerGoods/@signs')
                                      ,1
                                      ,35)                                                dangergoodssign
                              ,substr (extractvalue (value (a)
                                                    ,'/goods/dangerGoods/@packingGroup')
                                      ,1
                                      ,3)                                                 dangergoodspackinggroup
                              ,to_number (extractvalue (value (a)
                                                       ,'/goods/dangerGoods/@unCode'))    uncode
                              ,to_number (extractvalue (value (a)
                                                       ,'/goods/weightRailway'))          weightrailway
                              ,to_number (extractvalue (value (a)
                                                       ,'/goods/weightRailwayGross'))     weightrailwaygross
                              ,extract (value (a)
                                       ,'/goods')                                         goods
                          FROM TABLE (xmlsequence (p_xml.extract ('/message/waybill/goods'))) a)
        LOOP
            l_step                                                   :=
                'goods FOR c_goods position '
                || c_goods.position;
            p_smgs.goods.extend;
            p_smgs.goods (p_smgs.goods.count).position               := c_goods.position;
            p_smgs.goods (p_smgs.goods.count).gng                    := c_goods.gngcode;
            p_smgs.goods (p_smgs.goods.count).etsng                  := c_goods.etsngcode;
            p_smgs.goods (p_smgs.goods.count).railway_weight_gross   := c_goods.weightrailwaygross;
            p_smgs.goods (p_smgs.goods.count).railway_weight         := c_goods.weightrailway;

            p_smgs.goods (p_smgs.goods.count).danger_code            := c_goods.dangergoodscode;
            p_smgs.goods (p_smgs.goods.count).danger_crash_card      := c_goods.emergencycardcode;
            p_smgs.goods (p_smgs.goods.count).danger_un_code         := c_goods.uncode;
            p_smgs.goods (p_smgs.goods.count).danger_name            := c_goods.dangergoods;
            p_smgs.goods (p_smgs.goods.count).danger_class           := c_goods.dangergoodsclass;
            p_smgs.goods (p_smgs.goods.count).danger_sign            := c_goods.dangergoodssign;
            p_smgs.goods (p_smgs.goods.count).danger_packing_group   := c_goods.dangergoodspackinggroup;

            p_smgs.goods (p_smgs.goods.count).name                   := c_goods.description;
            p_smgs.goods (p_smgs.goods.count).state_dispatch         := c_goods.statedispatch;
            p_smgs.goods (p_smgs.goods.count).state_destination      := c_goods.statedestination;

            p_smgs.goods (p_smgs.goods.count).dangerous_goods_stamps := spv.smgs2_interface.tb_dangerous_goods_stamp ();

            FOR dangergoodsadditionaltext IN (SELECT substr (extractvalue (value (a)
                                                                          ,'/dangerGoodsAdditionalText')
                                                            ,1
                                                            ,350)    AS value
                                                FROM TABLE (xmlsequence (c_goods.goods.extract ('/goods/dangerGoodsAdditionalText'))) a)
            LOOP
                p_smgs.goods (p_smgs.goods.count).dangerous_goods_stamps.extend;
                p_smgs.goods (p_smgs.goods.count).dangerous_goods_stamps (p_smgs.goods (p_smgs.goods.count).dangerous_goods_stamps.count).position :=
                    p_smgs.goods (p_smgs.goods.count).dangerous_goods_stamps.count;
                p_smgs.goods (p_smgs.goods.count).dangerous_goods_stamps (p_smgs.goods (p_smgs.goods.count).dangerous_goods_stamps.count).label :=
                    dangergoodsadditionaltext.value;
            END LOOP;

            /* package */
            l_step                                                   :=
                'goods FOR c_goods position '
                || c_goods.position
                || ' and package';
            p_smgs.goods (p_smgs.goods.count).package                := spv.smgs2_interface.tb_edi_package ();

            FOR package IN (SELECT substr (extractvalue (value (a)
                                                        ,'/package/@code')
                                          ,1
                                          ,2)                             code
                                  ,extractvalue (value (a)
                                                ,'/package/@amount')      amount
                                  ,substr (extractvalue (value (a)
                                                        ,'/package')
                                          ,1
                                          ,35)                            description
                                  ,extractvalue (value (a)
                                                ,'/package/@edilevel')    edilevel
                                  ,substr (extractvalue (value (a)
                                                        ,'/package/@position')
                                          ,1
                                          ,3)                             positsioon
                              FROM TABLE (xmlsequence (c_goods.goods.extract ('/goods/package'))) a)
            LOOP
                l_step                                                                                                    :=
                    'goods FOR c_goods position '
                    || c_goods.position
                    || ' and FOR package with description '
                    || package.description;
                p_smgs.goods (p_smgs.goods.count).package.extend;
                p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).code          := package.code;
                p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).layer         := NULL;

                IF regexp_like (package.amount
                               ,'^\d+$')
                THEN
                    p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).amount := to_number (package.amount);
                ELSIF regexp_like (package.amount
                                  ,'^\d+\/\d+$')
                THEN
                    p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).amount :=
                        to_number (regexp_replace (package.amount
                                                  ,'^(\d+)\/(\d+)$'
                                                  ,'\1'));
                    p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).larged_packets_amount :=
                        to_number (regexp_replace (package.amount
                                                  ,'^(\d+)\/(\d+)$'
                                                  ,'\2'));
                END IF;

                p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).description   := package.description;

                -- Parse new "edilevel" and "positsioon" params
                p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).element_index := NULL;
                p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).positsioon    := NULL;

                -- Only applicable starting 1.9.1 version of the iftmin.xsd spec
                IF vjs.util.compare_version_tags (in_version_a => getparamvalue ('CURRENT_IFTMIN_XSD_VERSION'
                                                                                ,'1.9')
                                                 ,in_version_b => '1.9.1'
                                                 ,in_operator  => '>=')
                THEN
                    IF to_number (package.edilevel) > 0
                    THEN
                        -- EDIFACT GID segment data index is translated to edilevel for XML and vice versa (edilevel = element_index - 2)
                        p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).element_index :=
                            to_number (package.edilevel) + 2;
                    END IF;

                    IF to_number (package.positsioon) > 0
                    THEN
                        p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).positsioon := package.positsioon;
                    END IF;

                    IF package.edilevel = '2'
                    THEN
                        p_smgs.goods (p_smgs.goods.count).package (p_smgs.goods (p_smgs.goods.count).package.count).code := null;
                    END IF;
                END IF;
            END LOOP;

            /* label  */
            l_step                                                   :=
                'goods FOR c_goods position '
                || c_goods.position
                || ' and label';
            p_smgs.goods (p_smgs.goods.count).label                  := spv.smgs2_interface.tb_edi_label ();

            FOR label IN (SELECT substr (extractvalue (value (a)
                                                      ,'/label')
                                        ,1
                                        ,128)    description
                            FROM TABLE (xmlsequence (c_goods.goods.extract ('/goods/label'))) a)
            LOOP
                l_step                                                                                        :=
                    'goods FOR c_goods position '
                    || c_goods.position
                    || ' and FOR label with description '
                    || label.description;
                p_smgs.goods (p_smgs.goods.count).label.extend;

                p_smgs.goods (p_smgs.goods.count).label (p_smgs.goods (p_smgs.goods.count).label.count).label := label.description;
            END LOOP;

            -- description
            l_step                                                   :=
                'goods FOR c_goods position '
                || c_goods.position
                || ' and goods description text loop begins';
            l_goods_idx                                              := p_smgs.goods.count;
            p_smgs.goods (l_goods_idx).description_text              := spv.smgs2_interface.tb_edi_text ();
            p_smgs.goods (l_goods_idx).name_comment                  := spv.smgs2_interface.tb_edi_text ();

            FOR description IN (SELECT extractvalue (value (a)
                                                    ,'/description')          text
                                      ,rownum                                 rn
                                      ,extractvalue (value (a)
                                                    ,'/description/@no')      descr_no
                                      ,extractvalue (value (a)
                                                    ,'/description/@role')    smgs_role
                                  FROM TABLE (xmlsequence (c_goods.goods.extract ('/goods/description'))) a)
            LOOP
                l_step  :=
                    'goods FOR c_goods position '
                    || c_goods.position
                    || ' and FOR goods description text: '
                    || substr (description.text
                              ,1
                              ,20);
                l_tekst := description.text;

                IF    description.smgs_role = 'AAA'
                   OR description.descr_no = '1'
                   OR description.rn = 1
                THEN
                    -- AAA - mandatory segment
                    -- jaota description.text 350-steks description_text.text juppideks rolliga AAA
                    split_text_into_smgs (io_smgs  => p_smgs
                                         ,in_text  => l_tekst
                                         ,in_case  => 'GOODS.DESCRIPTION_TEXT'
                                         ,in_role  => 'AAA'
                                         ,in_index => l_goods_idx);
                ELSIF    description.smgs_role = 'PRD'
                      OR     description.smgs_role IS NULL
                         AND (   description.descr_no >= '2'
                              OR description.rn >= 2)
                THEN
                    -- jaota description.text 350-steks name_comment.text juppideks rolliga PRD
                    IF nvl (length (l_tekst), 0) > 0
                    THEN
                        split_text_into_smgs (io_smgs  => p_smgs
                                             ,in_text  => l_tekst
                                             ,in_case  => 'GOODS.NAME_COMMENT'
                                             ,in_role  => 'PRD'
                                             ,in_index => l_goods_idx);
                    END IF;
                ELSIF    description.smgs_role = 'ABJ'
                      OR description.descr_no = '3'
                      OR description.rn = 3
                THEN
                    -- jaota description.text 350-steks name_comment.text juppideks rolliga ABJ
                    IF nvl (length (l_tekst), 0) > 0
                    THEN
                        split_text_into_smgs (io_smgs  => p_smgs
                                             ,in_text  => l_tekst
                                             ,in_case  => 'GOODS.NAME_COMMENT'
                                             ,in_role  => 'ABJ'
                                             ,in_index => l_goods_idx);
                    END IF;
                ELSIF    description.smgs_role = 'AAZ'
                      OR description.descr_no = '4'
                      OR description.rn = 4
                THEN
                    -- jaota description.text 350-steks name_comment.text juppideks rolliga AAZ
                    IF nvl (length (l_tekst), 0) > 0
                    THEN
                        split_text_into_smgs (io_smgs  => p_smgs
                                             ,in_text  => l_tekst
                                             ,in_case  => 'GOODS.NAME_COMMENT'
                                             ,in_role  => 'AAZ'
                                             ,in_index => l_goods_idx);
                    END IF;
                END IF;
            END LOOP;
        END LOOP;

        /*wagons*/
        l_step             := 'wagons';

        FOR c_wagons IN (  SELECT to_number (extractvalue (value (a)
                                                          ,'/wagon/@position'))      position
                                 ,substr (extractvalue (value (a)
                                                       ,'/wagon/@number')
                                         ,1
                                         ,12)                                        wagon_nr
                                 ,substr (extractvalue (value (a)
                                                       ,'/wagon/@capacity')
                                         ,1
                                         ,8)                                         capacity
                                 ,substr (extractvalue (value (a)
                                                       ,'/wagon/@tareWeight')
                                         ,1
                                         ,8)                                         tareweight
                                 ,to_number (extractvalue (value (a)
                                                          ,'/wagon/@axis'))          axis
                                 ,to_number (extractvalue (value (a)
                                                          ,'/wagon/goodsWeight'))    goodsweight
                                 ,CASE
                                      WHEN nvl (smgs.dokum_kood, 'x') <> 'ZPN' -- exclusion for IFTMIN_PN
                                      THEN
                                          substr (extractvalue (value (a)
                                                               ,'/wagon/previousGoods')
                                                 ,1
                                                 ,350)
                                  END                                                previousgoods
                                 ,substr (extractvalue (value (a)
                                                       ,'/wagon/previousGoods/@gngCode')
                                         ,1
                                         ,350)                                       previousgngcode
                                 ,substr (extractvalue (value (a)
                                                       ,'/wagon/previousGoods/@etsngCode')
                                         ,1
                                         ,350)                                       previousetsngcode
                                 ,substr (extractvalue (value (a)
                                                       ,'/wagon/previousGoods/dangerGoods/@description')
                                         ,1
                                         ,350)                                       previousdangerdoodsdescr
                                 ,extractvalue (value (a)
                                               ,'/wagon/@notes')                     notes
                                 ,extractvalue (value (a)
                                               ,'/wagon/@tankCaliber')               tankcaliber
                                 ,substr (extractvalue (value (a)
                                                       ,'/wagon/@ownerInformation')
                                         ,1
                                         ,35)                                        ownerinformation
                                 ,substr (extractvalue (value (a)
                                                       ,'/wagon/@wagonProvider')
                                         ,1
                                         ,1)                                         wagonprovider
                                 ,substr (extractvalue (value (a)
                                                       ,'/wagon/@rwCode')
                                         ,1
                                         ,2)                                         rwcode
                                 ,extract (value (a)
                                          ,'/wagon')                                 wagons
                             FROM TABLE (xmlsequence (p_xml.extract ('/message/waybill/wagon'))) a
                         ORDER BY 1)
        LOOP
            l_step                                    :=
                'FOR wagons with wagon_nr '
                || c_wagons.wagon_nr;
            p_smgs.wagon.extend;
            z_wag_idx                                 := p_smgs.wagon.count;
            p_smgs.wagon (z_wag_idx).position         := c_wagons.position;
            p_smgs.wagon (z_wag_idx).wagon_nr         := c_wagons.wagon_nr;
            p_smgs.wagon (z_wag_idx).capacity         :=
                to_number (c_wagons.capacity
                          ,'99999D9999999999'
                          ,'nls_numeric_characters=''.,''');
            p_smgs.wagon (z_wag_idx).net_weight       :=
                to_number (c_wagons.tareweight
                          ,'99999D9999999999'
                          ,'nls_numeric_characters=''.,''');
            p_smgs.wagon (z_wag_idx).axis             := c_wagons.axis;
            p_smgs.wagon (z_wag_idx).goods_weight     := c_wagons.goodsweight;
            p_smgs.wagon (z_wag_idx).prev_etsng       := c_wagons.previousetsngcode;
            p_smgs.wagon (z_wag_idx).prev_gng         := c_wagons.previousgngcode;
            p_smgs.wagon (z_wag_idx).prev_desc        := c_wagons.previousgoods;

            p_smgs.wagon (z_wag_idx).prev_danger_desc := c_wagons.previousdangerdoodsdescr;
            p_smgs.wagon (z_wag_idx).notes            := c_wagons.notes;

            p_smgs.wagon (z_wag_idx).kalibr_code      := c_wagons.tankcaliber;
            p_smgs.wagon (z_wag_idx).owner_name       := c_wagons.ownerinformation;
            p_smgs.wagon (z_wag_idx).provider         := c_wagons.wagonprovider;
            p_smgs.wagon (z_wag_idx).rw_admin         := c_wagons.rwcode;

            /* leads */
            p_smgs.wagon (z_wag_idx).lead             := spv.smgs2_interface.tb_edi_lead ();

            FOR leads IN (SELECT substr (extractvalue (value (a)
                                                      ,'/lead/@owner')
                                        ,1
                                        ,2)                                    owner
                                ,to_number (extractvalue (value (a)
                                                         ,'/lead/@amount'))    amount
                                ,substr (extractvalue (value (a)
                                                      ,'/lead/@station')
                                        ,1
                                        ,6)                                    station
                                ,substr (extractvalue (value (a)
                                                      ,'/lead/sign')
                                        ,1
                                        ,256)                                  sign
                            FROM TABLE (xmlsequence (c_wagons.wagons.extract ('/wagon/lead'))) a)
            LOOP
                l_step :=
                    'FOR wagons with wagon_nr '
                    || c_wagons.wagon_nr
                    || ' and FOR leads '
                    || leads.sign;

                IF     leads.owner IN ('CA'
                                      ,'CZ'
                                      ,'CU'
                                      ,'SH')
                   AND (   leads.sign IS NOT NULL
                        OR getparamvalue ('SAATELEHTE_PLOMMI_NR_PARANDUS'
                                         ,'E') = 'J')
                THEN
                    p_smgs.wagon (z_wag_idx).lead.extend;
                    z_lead_idx                                         := p_smgs.wagon (z_wag_idx).lead.count;
                    -- "IFTMIN 97A loplik" dokumendi tottu lubatud plommide tunnused on CA,CU ja SH
                    p_smgs.wagon (z_wag_idx).lead (z_lead_idx).owner   :=
                        replace (leads.owner
                                ,'CZ'
                                ,'SH');
                    p_smgs.wagon (z_wag_idx).lead (z_lead_idx).amount  := leads.amount;
                    p_smgs.wagon (z_wag_idx).lead (z_lead_idx).station := leads.station;
                    p_smgs.wagon (z_wag_idx).lead (z_lead_idx).lead_nr := leads.sign;
                END IF;
            END LOOP;

            -- equipment with containerType
            p_smgs.wagon (z_wag_idx).container        := spv.smgs2_interface.tb_edi_container ();

            FOR equipments IN (SELECT extractvalue (value (a)
                                                   ,'/equipment/@position')                       position
                                     ,substr (extractvalue (value (a)
                                                           ,'/equipment/@ownershipType')
                                             ,1
                                             ,1)                                                  ownershiptype
                                     ,substr (extractvalue (value (a)
                                                           ,'/equipment/@country')
                                             ,1
                                             ,3)                                                  country
                                     ,substr (extractvalue (value (a)
                                                           ,'/equipment/@renter')
                                             ,1
                                             ,128)                                                renter
                                     ,substr (extractvalue (value (a)
                                                           ,'/equipment/@number')
                                             ,1
                                             ,12)                                                 eq_number
                                     ,extractvalue (value (a)
                                                   ,'/equipment/@quantity')                       quantity
                                     ,substr (extractvalue (value (a)
                                                           ,'/equipment/@tareWeight')
                                             ,1
                                             ,5)                                                  tareweight
                                     ,substr (extractvalue (value (a)
                                                           ,'/equipment/type/@description')
                                             ,1
                                             ,128)                                                type_description
                                     ,substr (extractvalue (value (a)
                                                           ,'/equipment/type/containerType/@sizeCode')
                                             ,1
                                             ,2)                                                  cont_sizecode
                                     ,substr (extractvalue (value (a)
                                                           ,'/equipment/type/containerType/@typeCode')
                                             ,1
                                             ,2)                                                  cont_typecode
                                     ,extractvalue (value (a)
                                                   ,'/equipment/type/containerType/@capacity')    cont_capacity
                                     ,extractvalue (value (a)
                                                   ,'/equipment/type/containerType/@length')      cont_length
                                     ,extractvalue (value (a)
                                                   ,'/equipment/goodsWeight')                     goodsweight
                                     ,extract (value (a)
                                              ,'/equipment/lead')                                 leads
                                 FROM TABLE (xmlsequence (c_wagons.wagons.extract ('/wagon/equipment'))) a
                                WHERE existsnode (value (a)
                                                 ,'/equipment/type/containerType') = 1)
            LOOP
                l_step                                                         :=
                    'FOR wagons with wagon_nr '
                    || c_wagons.wagon_nr
                    || ' and FOR equipments with containerType and position'
                    || equipments.position;
                p_smgs.wagon (z_wag_idx).container.extend;
                z_cont_idx                                                     := p_smgs.wagon (z_wag_idx).container.count;

                p_smgs.wagon (z_wag_idx).container (z_cont_idx).position       := to_number (equipments.position);
                p_smgs.wagon (z_wag_idx).container (z_cont_idx).container_nr   := equipments.eq_number;
                p_smgs.wagon (z_wag_idx).container (z_cont_idx).net_weight     := to_number (equipments.tareweight);
                p_smgs.wagon (z_wag_idx).container (z_cont_idx).type           :=
                    equipments.cont_sizecode
                    || equipments.cont_typecode;
                p_smgs.wagon (z_wag_idx).container (z_cont_idx).length         := to_number (equipments.cont_length);
                p_smgs.wagon (z_wag_idx).container (z_cont_idx).goods_weight   := to_number (equipments.goodsweight);
                p_smgs.wagon (z_wag_idx).container (z_cont_idx).ownership_form := equipments.ownershiptype;

                /* container leads */
                p_smgs.wagon (z_wag_idx).container (z_cont_idx).lead           := spv.smgs2_interface.tb_edi_lead ();

                /* leads */
                FOR leads IN (SELECT substr (extractvalue (value (a)
                                                          ,'/lead/@owner')
                                            ,1
                                            ,2)                                    owner
                                    ,to_number (extractvalue (value (a)
                                                             ,'/lead/@amount'))    amount
                                    ,substr (extractvalue (value (a)
                                                          ,'/lead/@station')
                                            ,1
                                            ,6)                                    station
                                    ,substr (extractvalue (value (a)
                                                          ,'/lead/sign')
                                            ,1
                                            ,128)                                  sign
                                FROM TABLE (xmlsequence (equipments.leads.extract ('/lead'))) a)
                LOOP
                    l_step :=
                        'FOR wagons with wagon_nr '
                        || c_wagons.wagon_nr
                        || ' and FOR equipments with position'
                        || equipments.position
                        || ' and FOR leads '
                        || leads.sign;

                    IF     leads.owner IN ('CA'
                                          ,'CZ'
                                          ,'CU'
                                          ,'SH')
                       AND leads.sign IS NOT NULL
                    THEN
                        p_smgs.wagon (z_wag_idx).container (z_cont_idx).lead.extend;
                        z_lead_idx                                                                := p_smgs.wagon (z_wag_idx).container (z_cont_idx).lead.count;
                        p_smgs.wagon (z_wag_idx).container (z_cont_idx).lead (z_lead_idx).lead_nr := leads.sign;
                        p_smgs.wagon (z_wag_idx).container (z_cont_idx).lead (z_lead_idx).owner   :=
                            replace (leads.owner
                                    ,'CZ'
                                    ,'SH');
                        p_smgs.wagon (z_wag_idx).container (z_cont_idx).lead (z_lead_idx).amount  := leads.amount;
                        p_smgs.wagon (z_wag_idx).container (z_cont_idx).lead (z_lead_idx).station := leads.station;
                    END IF;
                END LOOP;
            END LOOP;

            -- equipment with equipmentType
            p_smgs.wagon (z_wag_idx).equipment        := spv.smgs2_interface.tb_edi_equipment ();

            FOR r_equipment IN (SELECT extractvalue (value (a)
                                                    ,'/equipment/@position')    position
                                      ,substr (extractvalue (value (a)
                                                            ,'/equipment/@ownershipType')
                                              ,1
                                              ,1)                               ownershiptype
                                      ,substr (extractvalue (value (a)
                                                            ,'/equipment/@number')
                                              ,1
                                              ,12)                              eq_number
                                      ,substr (extractvalue (value (a)
                                                            ,'/equipment/@tareWeight')
                                              ,1
                                              ,5)                               tareweight
                                      ,substr (extractvalue (value (a)
                                                            ,'/equipment/type/equipmentType')
                                              ,1
                                              ,3)                               equipmenttype_text
                                      ,substr (extractvalue (value (a)
                                                            ,'/equipment/type/equipmentType/@description')
                                              ,1
                                              ,350)                             equipmenttype_descr
                                  FROM TABLE (xmlsequence (c_wagons.wagons.extract ('/wagon/equipment'))) a
                                 WHERE existsnode (value (a)
                                                  ,'/equipment/type/equipmentType') = 1)
            LOOP
                l_step                                                               :=
                    'FOR wagons with wagon_nr '
                    || c_wagons.wagon_nr
                    || ' and FOR equipments with equipmentType and position'
                    || r_equipment.position;
                p_smgs.wagon (z_wag_idx).equipment.extend;
                l_equip_idx                                                          := p_smgs.wagon (z_wag_idx).equipment.count;

                p_smgs.wagon (z_wag_idx).equipment (l_equip_idx).position            := nvl (tonumber (r_equipment.position), 1);
                p_smgs.wagon (z_wag_idx).equipment (l_equip_idx).ownership_form      := nvl (r_equipment.ownershiptype, 'P');
                p_smgs.wagon (z_wag_idx).equipment (l_equip_idx).equipment_nr        := nvl (r_equipment.eq_number, '0');
                p_smgs.wagon (z_wag_idx).equipment (l_equip_idx).tare_weight         := tonumber (r_equipment.tareweight);
                p_smgs.wagon (z_wag_idx).equipment (l_equip_idx).equipmenttype_text  := nvl (r_equipment.equipmenttype_text, 'EFP');
                p_smgs.wagon (z_wag_idx).equipment (l_equip_idx).equipmenttype_descr := r_equipment.equipmenttype_descr;
            END LOOP;
        END LOOP;

        /* texts */
        l_step             := 'texts';

        -- p_smgs.text(i).text võib olla kuni 4000 baiti = cyrillic sümboleid 2000 - seetõttu substr 2000
        -- kuna FTX+TRA võib kokku olla pikem kui 2000 sümbolit, peab kasutama CLOB muutujat
        FOR c_text IN (SELECT substr (extractvalue (value (a)
                                                   ,'/text/@role')
                                     ,1
                                     ,3)       smgs_role
                             ,substr (extractvalue (value (a)
                                                   ,'/text')
                                     ,1
                                     ,2000)    text
                         FROM TABLE (xmlsequence (p_xml.extract ('/message/waybill/text'))) a
                        WHERE substr (extractvalue (value (a)
                                                   ,'/text/@role')
                                     ,1
                                     ,3) IN ('AAO'
                                            ,'ICN'
                                            ,'DCL'
                                            ,'AAH'
                                            ,'AEA'
                                            ,'BLR'))
        LOOP
            CASE
                WHEN     c_text.smgs_role IN ('AEA'
                                             ,'BLR')
                     AND length (c_text.text) > 350
                THEN
                    -- generate warning message and cut off surplus text
                    l_step                          :=
                        'FOR c_text AEA/BLR '
                        || p_smgs.text.count
                        || ' with smgs_role '
                        || c_text.smgs_role;
                    add_message (p_message        => nvl (vjs.vjs_tekstid$.get_tekst (p_kood     => 'TEXT_LENGTH_OVER_LIMIT'
                                                                                     ,p_kontekst => 'SAATELEHTEDE_HALDUS'
                                                                                     ,p_keel     => get_kasutaja_keel ()
                                                                                     ,p_par1     => p_smgs.smgs_number
                                                                                     ,p_par2     => c_text.smgs_role
                                                                                     ,p_par3     => '350')
                                                         ,'Sõnumi nr '
                                                          || p_smgs.smgs_number
                                                          || ' tekst rolliga '
                                                          || c_text.smgs_role
                                                          || ' pikkus on üle lubatud 350 !')
                                ,p_realm          => 'warning'
                                ,p_code           => '-20000'
                                ,p_www_tekstid_id => NULL);

                    p_smgs.text.extend;
                    z_index                         := p_smgs.text.count;
                    p_smgs.text (z_index).smgs_role := c_text.smgs_role;
                    p_smgs.text (z_index).text      :=
                        substr (c_text.text
                               ,1
                               ,350);
                WHEN     c_text.smgs_role = 'DCL'
                     AND length (c_text.text) > 350
                THEN
                    l_step  := 'c_text.smgs_role = DCL and length > 350';
                    l_tekst := c_text.text;
                    l_text_max_length_dcl :=
                        getparamvalue ('IFTMIN_SENDER_STATEMENT_MAX'
                                      ,'1050');

                    IF nvl (length (l_tekst), 0) > l_text_max_length_dcl
                    THEN
                        l_tekst :=
                            substr (l_tekst
                                   ,1
                                   ,l_text_max_length_dcl);
                        add_message (p_message        => nvl (vjs.vjs_tekstid$.get_tekst (p_kood     => 'TEXT_LENGTH_OVER_LIMIT'
                                                                                         ,p_kontekst => 'SAATELEHTEDE_HALDUS'
                                                                                         ,p_keel     => get_kasutaja_keel ()
                                                                                         ,p_par1     => p_smgs.smgs_number
                                                                                         ,p_par2     => c_text.smgs_role
                                                                                         ,p_par3     => l_text_max_length_dcl)
                                                             ,'Sõnumi nr '
                                                              || p_smgs.smgs_number
                                                              || ' tekst rolliga '
                                                              || c_text.smgs_role
                                                              || ' pikkus on üle lubatud '
                                                              || l_text_max_length_dcl
                                                              || ' !')
                                    ,p_realm          => 'warning'
                                    ,p_code           => '-20000'
                                    ,p_www_tekstid_id => NULL);
                    END IF;

                    FOR i IN 1 .. 30
                    LOOP
                        l_step                          :=
                            'FOR c_text DCL '
                            || p_smgs.text.count;
                        p_smgs.text.extend;
                        z_index                         := p_smgs.text.count;
                        p_smgs.text (z_index).smgs_role := c_text.smgs_role;
                        p_smgs.text (z_index).text      :=
                            substr (l_tekst
                                   ,1
                                   ,350);
                        EXIT WHEN length (l_tekst) < 351;
                        l_tekst                         :=
                            substr (l_tekst
                                   ,351);
                    END LOOP;
                ELSE
                    l_step                          :=
                        'FOR c_text ELSE '
                        || p_smgs.text.count;
                    p_smgs.text.extend;
                    z_index                         := p_smgs.text.count;
                    p_smgs.text (z_index).smgs_role := c_text.smgs_role;
                    p_smgs.text (z_index).text      := c_text.text;
            END CASE;
        END LOOP;

        l_text_role        := 'TRA';
        l_step             :=
            'text '
            || l_text_role;

        dbms_lob.createtemporary (l_text_clob
                                 ,TRUE);

        l_text_clob_do     := 'Y';

        BEGIN
                SELECT xmlt.vals
                  INTO l_text_clob
                  FROM xmltable ('/message/waybill/text'
                                 PASSING p_xml
                                 COLUMNS vals       CLOB PATH 'text()'
                                        ,text_role  VARCHAR2 (3) PATH '@role') xmlt
                 WHERE     xmlt.text_role = l_text_role
                       AND rownum = 1;
        EXCEPTION
            WHEN no_data_found
            THEN
                l_text_clob_do := 'N';
        END;

        IF l_text_clob_do = 'Y'
        THEN
            l_clob_offset := 1;
            l_clob_length := nvl (dbms_lob.getlength (l_text_clob), 0);

            FOR i IN 1 .. 90
            LOOP
                l_step                          :=
                    'IF l_text_clob_do '
                    || p_smgs.text.count
                    || ' with smgs_role '
                    || l_text_role;
                p_smgs.text.extend;
                z_index                         := p_smgs.text.count;
                p_smgs.text (z_index).smgs_role := l_text_role;
                p_smgs.text (z_index).text      :=
                    dbms_lob.substr (l_text_clob
                                    ,350
                                    ,l_clob_offset);

                l_clob_offset                   := l_clob_offset + 350;

                EXIT WHEN l_clob_length < l_clob_offset;
            END LOOP;

                SELECT count (*)
                  INTO l_text_cnt
                  FROM xmltable ('/message/waybill/text'
                                 PASSING p_xml
                                 COLUMNS vals       CLOB PATH 'text()'
                                        ,text_role  VARCHAR2 (3) PATH '@role') xmlt
                 WHERE xmlt.text_role = l_text_role;

            IF l_text_cnt > 1
            THEN
                add_message (p_message        => nvl (vjs.vjs_tekstid$.get_tekst (p_kood     => 'TEXT_XML_ELEMENTS_OVER_LIMIT'
                                                                                 ,p_kontekst => 'SAATELEHTEDE_HALDUS'
                                                                                 ,p_keel     => get_kasutaja_keel ()
                                                                                 ,p_par1     => p_smgs.smgs_number
                                                                                 ,p_par2     => l_text_role
                                                                                 ,p_par3     => '1')
                                                     ,'Sõnumi nr '
                                                      || p_smgs.smgs_number
                                                      || ' tekst rolliga '
                                                      || l_text_role
                                                      || ' XML-elemente on rohkem kui lubatud 1 !')
                            ,p_realm          => 'warning'
                            ,p_code           => '-20000'
                            ,p_www_tekstid_id => NULL);
            END IF;
        END IF;

        l_text_clob        := ' ';
        dbms_lob.freetemporary (l_text_clob);

        /* documents */
        l_step             := 'documents';

        FOR c_documents IN (SELECT substr (extractvalue (value (a)
                                                        ,'/documentAdded/@role')
                                          ,1
                                          ,3)                                             smgs_role
                                  ,extractvalue (value (a)
                                                ,'/documentAdded/@number')                docnumber
                                  ,extractvalue (value (a)
                                                ,'/documentAdded/@date')                  doc_date
                                  ,to_number (extractvalue (value (a)
                                                           ,'/documentAdded/@format'))    format
                                  ,extractvalue (value (a)
                                                ,'/documentAdded/text()')                 doc_name
                                  ,to_number (extractvalue (value (a)
                                                           ,'/documentAdded/@count'))     doc_count
                              FROM TABLE (xmlsequence (p_xml.extract ('/message/waybill/documentAdded'))) a)
        LOOP
            l_step                              :=
                'FOR c_documents '
                || p_smgs.document.count;
            p_smgs.document.extend;
            z_index                             := p_smgs.document.count;
            p_smgs.document (z_index).code      := c_documents.smgs_role;
            p_smgs.document (z_index).docnumber := c_documents.docnumber;
            p_smgs.document (z_index).created_at :=
                to_date (c_documents.doc_date
                        ,'dd.mm.yyyy');
            p_smgs.document (z_index).doc_type  := c_documents.format;
            p_smgs.document (z_index).doc_name  := c_documents.doc_name;
            p_smgs.document (z_index).doc_count := c_documents.doc_count;
        END LOOP;

        RETURN p_smgs;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.xml_to_var'
                                            ,p_params => l_params);
            RETURN NULL;
    END xml_to_var;

    PROCEDURE collections_to_xml (p_xml IN OUT XMLTYPE)
    IS
        z_xml_element     XMLTYPE;
        z_xml_danger      XMLTYPE;
        z_xml_pack        XMLTYPE;
        z_xml_label       XMLTYPE;
        z_xml_wagon       XMLTYPE;
        z_xml_lead        XMLTYPE;
        z_xml_container   XMLTYPE;
        z_xml_station     XMLTYPE;
        z_xml_participant XMLTYPE;
        z_xml_undertacker XMLTYPE;
        z_xml_code        XMLTYPE;
        z_count           INTEGER;
        l_params          logger_service.logger.tab_param;
        l_step            VARCHAR2 (300);

        FUNCTION add_station (p_element_name IN VARCHAR2
                             ,p_code6           VARCHAR2
                             ,p_name            VARCHAR2
                             ,p_state           VARCHAR2
                             ,p_rwadmin         VARCHAR2)
            RETURN XMLTYPE
        IS
            p_station_element XMLTYPE
                                  := xmltype ('<'
                                              || p_element_name
                                              || '></'
                                              || p_element_name
                                              || '>');
        BEGIN
            l_step := 'insert_attribute code';
            insert_attribute (p_station_element
                             ,'/'
                              || p_element_name
                             ,'code'
                             ,p_code6
                             ,TRUE);
            l_step := 'insert_element name';
            insert_element (p_station_element
                           ,'/'
                            || p_element_name
                           ,'name'
                           ,xmltype ('<name>'
                                     || dbms_xmlgen.convert (p_name)
                                     || '</name>'));

            l_step := 'insert_element state';

            IF p_state IS NOT NULL
            THEN
                insert_element (p_station_element
                               ,'/'
                                || p_element_name
                               ,'state'
                               ,xmltype ('<state>'
                                         || p_state
                                         || '</state>'));
            END IF;

            l_step := 'insert_element rwAdmin';
            insert_element (p_station_element
                           ,'/'
                            || p_element_name
                           ,'rwAdmin'
                           ,xmltype ('<rwAdmin>'
                                     || p_rwadmin
                                     || '</rwAdmin>'));
            RETURN p_station_element;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.append_param (l_params
                                                   ,'p_element_name IN'
                                                   ,p_element_name);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.collections_to_xml - add_station'
                                                ,p_params => l_params);
        END add_station;

        FUNCTION add_participant (p_element_name IN VARCHAR2
                                 ,p_seq_id       IN INTEGER)
            RETURN XMLTYPE
        IS
            p_participant XMLTYPE
                              := xmltype ('<'
                                          || p_element_name
                                          || '></'
                                          || p_element_name
                                          || '>');
            p_address     XMLTYPE;
            p_code        XMLTYPE;
        BEGIN
            FOR p_data IN (SELECT c001     code4
                                 ,c002     name
                                 ,c005     state
                                 ,c006     street
                                 ,c007     city
                                 ,c008     zipcode
                                 ,c009     telefon
                                 ,c010     fax
                                 ,c011     email
                                 ,c012     reg_code
                                 ,c014     signature
                                 ,c015     e_document
                                 ,c050     unique_key
                             FROM apex_collections
                            WHERE     collection_name = smgs2_interface.participants_coll_name
                                  AND seq_id = p_seq_id)
            LOOP
                l_step    :=
                    'FOR p_data '
                    || p_data.unique_key
                    || ' and insert_element name';
                insert_element (p_participant
                               ,'/'
                                || p_element_name
                               ,'name'
                               ,xmltype ('<name>'
                                         || dbms_xmlgen.convert (p_data.name)
                                         || '</name>'));

                IF p_data.signature IS NOT NULL
                THEN
                    l_step :=
                        'FOR p_data '
                        || p_data.unique_key
                        || ' and insert_element signature';
                    insert_element (p_participant
                                   ,'/'
                                    || p_element_name
                                   ,'signature'
                                   ,xmltype ('<signature>'
                                             || dbms_xmlgen.convert (p_data.signature)
                                             || '</signature>'));
                END IF;

                l_step    :=
                    'FOR p_data '
                    || p_data.unique_key
                    || ' and address';
                p_address := xmltype ('<address/>');
                insert_attribute (p_address
                                 ,'/address'
                                 ,'state'
                                 ,dbms_xmlgen.convert (p_data.state)
                                 ,TRUE);
                insert_attribute (p_address
                                 ,'/address'
                                 ,'city'
                                 ,dbms_xmlgen.convert (p_data.city)
                                 ,TRUE);
                insert_attribute (p_address
                                 ,'/address'
                                 ,'street'
                                 ,dbms_xmlgen.convert (p_data.street)
                                 ,TRUE);
                insert_attribute (p_address
                                 ,'/address'
                                 ,'zipcode'
                                 ,p_data.zipcode
                                 ,TRUE);
                insert_attribute (p_address
                                 ,'/address'
                                 ,'telefon'
                                 ,p_data.telefon
                                 ,TRUE);
                insert_attribute (p_address
                                 ,'/address'
                                 ,'fax'
                                 ,p_data.fax);
                insert_attribute (p_address
                                 ,'/address'
                                 ,'email'
                                 ,dbms_xmlgen.convert (p_data.email));

                insert_element (p_participant
                               ,'/'
                                || p_element_name
                               ,'address'
                               ,p_address);

                /* participant codes*/
                FOR p_code IN (SELECT c002 code_type, c003 code_value
                                 FROM apex_collections
                                WHERE     collection_name = smgs2_interface.participants_codes_coll_name
                                      AND c001 = p_data.unique_key)
                LOOP
                    l_step  :=
                        'FOR p_data '
                        || p_data.unique_key
                        || ' and p_code '
                        || p_data.unique_key;
                    z_xml_code :=
                        xmltype ('<code>'
                                 || p_code.code_value
                                 || '</code>');
                    insert_attribute (z_xml_code
                                     ,'/code'
                                     ,'type'
                                     ,p_code.code_type
                                     ,TRUE);
                    insert_element (p_participant
                                   ,'/'
                                    || p_element_name
                                   ,'code'
                                   ,z_xml_code);
                    z_count := z_count + 1;
                END LOOP;

                l_step    :=
                    'FOR p_data '
                    || p_data.unique_key
                    || ' and p_data.code4 IS NOT NULL';

                IF     z_count < 1
                   AND p_data.code4 IS NOT NULL
                THEN
                    z_xml_code :=
                        xmltype ('<code>'
                                 || p_data.code4
                                 || '</code>');
                    insert_attribute (z_xml_code
                                     ,'/code'
                                     ,'type'
                                     ,'Z01'
                                     ,TRUE);
                    insert_element (p_participant
                                   ,'/'
                                    || p_element_name
                                   ,'code'
                                   ,z_xml_code);
                END IF;
            END LOOP;

            RETURN p_participant;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_params := logger_service.logger.gc_empty_tab_param;
                logger_service.logger.append_param (l_params
                                                   ,'l_step'
                                                   ,l_step);
                logger_service.logger.append_param (l_params
                                                   ,'p_element_name IN'
                                                   ,p_element_name);
                logger_service.logger.append_param (l_params
                                                   ,'p_seq_id       IN'
                                                   ,p_seq_id);
                logger_service.logger.log_error (p_text   => sqlerrm
                                                ,p_scope  => 'spv.'
                                                            || $$plsql_unit
                                                            || '.collections_to_xml - add_participant'
                                                ,p_params => l_params);
        END add_participant;
    BEGIN
        p_xml := xmltype ('<waybill></waybill>');

        FOR param IN (SELECT to_date (c001
                                     ,'dd.mm.yyyy')    created_at
                            ,substr (c002
                                    ,1
                                    ,6)                status
                            ,substr (c003
                                    ,1
                                    ,35)               smgs_number
                            ,substr (c004
                                    ,1
                                    ,35)               contract_nr
                            ,substr (c007
                                    ,1
                                    ,3)                who_loaded
                            ,substr (c008
                                    ,1
                                    ,3)                smgs_type
                            ,substr (c009
                                    ,1
                                    ,6)                s_station_code
                            ,substr (c010
                                    ,1
                                    ,70)               s_station_name
                            ,substr (c011
                                    ,1
                                    ,2)                s_station_rwadmin
                            ,substr (c012
                                    ,1
                                    ,6)                d_station_code
                            ,substr (c013
                                    ,1
                                    ,70)               d_station_name
                            ,substr (c014
                                    ,1
                                    ,2)                d_station_rwadmin
                            ,substr (c020
                                    ,1
                                    ,1)                saad_funk_kood
                            ,v ('P4_SONUM_ID')         edi_id
                        FROM apex_collections
                       WHERE     collection_name = smgs2_interface.common_coll_name
                             AND seq_id = 1)
        LOOP
            l_step :=
                'FOR param.edi_id '
                || param.edi_id;
            insert_attribute (p_xml
                             ,'/waybill'
                             ,'number'
                             ,param.smgs_number
                             ,TRUE);

            insert_attribute (p_xml
                             ,'/waybill'
                             ,'sendingType'
                             ,param.smgs_type
                             ,TRUE);

            insert_attribute (p_xml
                             ,'/waybill'
                             ,'messageFunction'
                             ,nvl (param.saad_funk_kood, '9')
                             ,TRUE);

            insert_attribute (p_xml
                             ,'/waybill'
                             ,'transportationSpeed'
                             ,NULL
                             ,TRUE);

            insert_attribute (p_xml
                             ,'/waybill'
                             ,'sendingDate'
                             ,to_char (param.created_at
                                      ,'dd.mm.yyyy')
                             ,TRUE);
            insert_attribute (p_xml
                             ,'/waybill'
                             ,'loadedBy'
                             ,param.who_loaded
                             ,TRUE);

            insert_attribute (p_xml
                             ,'/waybill'
                             ,'senderPayments'
                             ,NULL);
        END LOOP;

        -- stationDeparture
        FOR dep_station IN (  SELECT c003 station_name, c002 station_code, c007 rw_admin, c006 state, c005 smgs_role
                                FROM apex_collections
                               WHERE     collection_name = smgs2_interface.stations_coll_name
                                     AND c004 = '5'
                            ORDER BY seq_id)
        LOOP
            l_step :=
                'FOR dep_station.station_code '
                || dep_station.station_code;
            insert_element (p_xml
                           ,'/waybill'
                           ,'stationDeparture'
                           ,add_station (p_element_name => 'stationDeparture'
                                        ,p_code6        => dep_station.station_code
                                        ,p_name         => dep_station.station_name
                                        ,p_state        => dep_station.state
                                        ,p_rwadmin      => dep_station.rw_admin));
        END LOOP;

        -- stationDestination
        FOR des_station IN (  SELECT c003 station_name, c002 station_code, c007 rw_admin, c006 state, c005 smgs_role
                                FROM apex_collections
                               WHERE     collection_name = smgs2_interface.stations_coll_name
                                     AND c004 = '8'
                            ORDER BY seq_id)
        LOOP
            l_step :=
                'FOR des_station.station_code '
                || des_station.station_code;
            insert_element (p_xml
                           ,'/waybill'
                           ,'stationDestination'
                           ,add_station (p_element_name => 'stationDestination'
                                        ,p_code6        => des_station.station_code
                                        ,p_name         => des_station.station_name
                                        ,p_state        => des_station.state
                                        ,p_rwadmin      => des_station.rw_admin));
        END LOOP;

        -- Texts
        FOR txt IN (SELECT c002 smgs_role, c001 value
                      FROM apex_collections
                     WHERE collection_name = smgs2_interface.texts_coll_name)
        LOOP
            l_step :=
                'FOR txt.smgs_role '
                || txt.smgs_role;

            IF txt.value = 'IRP'
            THEN
                insert_attribute (p_xml
                                 ,'/waybill'
                                 ,'weightDetermined'
                                 ,txt.value);
            ELSIF txt.value = 'HAN'
            THEN
                insert_attribute (p_xml
                                 ,'/waybill'
                                 ,'paperFree'
                                 ,txt.value);
            END IF;
        END LOOP;

        -- border stations
        FOR b_station IN (  SELECT c001 station_name, c002 station_code, c003 rw_admin, c004 state, c005 smgs_role
                              FROM apex_collections
                             WHERE     collection_name = smgs2_interface.border_station_coll_name
                                   AND c005 = '17'
                          ORDER BY seq_id)
        LOOP
            l_step :=
                'FOR b_station.smgs_role = 17 and b_station.station_code '
                || b_station.station_code;
            insert_element (p_xml
                           ,'/waybill'
                           ,'stationBorder'
                           ,add_station (p_element_name => 'stationBorder'
                                        ,p_code6        => b_station.station_code
                                        ,p_name         => b_station.station_name
                                        ,p_state        => b_station.state
                                        ,p_rwadmin      => b_station.rw_admin));
        END LOOP;

        -- stationTransitBorderOut stations
        FOR b_station IN (  SELECT c001 station_name, c002 station_code, c003 rw_admin, c004 state, c005 smgs_role
                              FROM apex_collections
                             WHERE     collection_name = smgs2_interface.border_station_coll_name
                                   AND c005 = '42'
                          ORDER BY seq_id)
        LOOP
            l_step :=
                'FOR b_station.smgs_role = 42 and b_station.station_code '
                || b_station.station_code;
            insert_element (p_xml
                           ,'/waybill'
                           ,'stationTransitBorderOut'
                           ,add_station (p_element_name => 'stationTransitBorderOut'
                                        ,p_code6        => b_station.station_code
                                        ,p_name         => b_station.station_name
                                        ,p_state        => b_station.state
                                        ,p_rwadmin      => b_station.rw_admin));
        END LOOP;

        -- stationTransitBorderIn stations
        FOR b_station IN (  SELECT c001 station_name, c002 station_code, c003 rw_admin, c004 state, c005 smgs_role
                              FROM apex_collections
                             WHERE     collection_name = smgs2_interface.border_station_coll_name
                                   AND c005 = '41'
                          ORDER BY seq_id)
        LOOP
            l_step :=
                'FOR b_station.smgs_role = 41 and b_station.station_code '
                || b_station.station_code;
            insert_element (p_xml
                           ,'/waybill'
                           ,'stationTransitBorderIn'
                           ,add_station (p_element_name => 'stationTransitBorderIn'
                                        ,p_code6        => b_station.station_code
                                        ,p_name         => b_station.station_name
                                        ,p_state        => b_station.state
                                        ,p_rwadmin      => b_station.rw_admin));
        END LOOP;

        -- goods
        FOR goods IN (  SELECT c001     position
                              ,c002     gng
                              ,c003     etsng
                              ,c004     client_weight
                              ,c005     railway_weight
                              ,c015     state_dispatch
                              ,c016     state_destination
                              ,c006     danger_code
                              ,c007     danger_crash_card
                              ,c008     danger_un_code
                              ,c009     goods_name
                              ,c010     danger_name
                              ,c011     danger_class
                              ,c012     danger_sign
                              ,c013     danger_packing_group
                              ,c050     unique_key
                          FROM apex_collections
                         WHERE collection_name = smgs2_interface.goods_coll_name
                      ORDER BY seq_id)
        LOOP
            l_step        :=
                'FOR goods.unique_key '
                || goods.unique_key;
            z_xml_element := xmltype ('<goods></goods>');
            insert_element (z_xml_element
                           ,'/goods'
                           ,'description'
                           ,xmltype ('<description>'
                                     || dbms_xmlgen.convert (goods.goods_name)
                                     || '</description>'));
            --gngCode
            insert_attribute (z_xml_element
                             ,p_path      => '/goods'
                             ,p_attr_name => 'gngCode'
                             ,p_attr_val  => goods.gng
                             ,p_mandatory => TRUE);
            --etsngCode
            insert_attribute (z_xml_element
                             ,p_path      => '/goods'
                             ,p_attr_name => 'etsngCode'
                             ,p_attr_val  => goods.etsng
                             ,p_mandatory => TRUE);
            --position
            insert_attribute (z_xml_element
                             ,p_path      => '/goods'
                             ,p_attr_name => 'position'
                             ,p_attr_val  => goods.position
                             ,p_mandatory => TRUE);
            --stateDispatch
            insert_attribute (z_xml_element
                             ,p_path      => '/goods'
                             ,p_attr_name => 'stateDispatch'
                             ,p_attr_val  => goods.state_dispatch
                             ,p_mandatory => TRUE);
            --stateDispatch
            insert_attribute (z_xml_element
                             ,p_path      => '/goods'
                             ,p_attr_name => 'stateDestination'
                             ,p_attr_val  => goods.state_destination
                             ,p_mandatory => TRUE);

            IF goods.danger_name IS NOT NULL
            THEN
                z_xml_danger :=
                    xmltype ('<dangerGoods>'
                             || dbms_xmlgen.convert (goods.danger_name)
                             || '</dangerGoods>');
                insert_attribute (z_xml_danger
                                 ,p_path      => '/dangerGoods'
                                 ,p_attr_name => 'emergencyCardCode'
                                 ,p_attr_val  => goods.danger_crash_card
                                 ,p_mandatory => TRUE);
                insert_attribute (z_xml_danger
                                 ,p_path      => '/dangerGoods'
                                 ,p_attr_name => 'unCode'
                                 ,p_attr_val  => goods.danger_un_code
                                 ,p_mandatory => TRUE);
                insert_attribute (z_xml_danger
                                 ,p_path      => '/dangerGoods'
                                 ,p_attr_name => 'class'
                                 ,p_attr_val  => goods.danger_class
                                 ,p_mandatory => FALSE);
                insert_attribute (z_xml_danger
                                 ,p_path      => '/dangerGoods'
                                 ,p_attr_name => 'signs'
                                 ,p_attr_val  => goods.danger_sign
                                 ,p_mandatory => FALSE);
                insert_attribute (z_xml_danger
                                 ,p_path      => '/dangerGoods'
                                 ,p_attr_name => 'code'
                                 ,p_attr_val  => goods.danger_code
                                 ,p_mandatory => FALSE);
                insert_attribute (z_xml_danger
                                 ,p_path      => '/dangerGoods'
                                 ,p_attr_name => 'packingGroup'
                                 ,p_attr_val  => goods.danger_packing_group
                                 ,p_mandatory => FALSE);

                insert_element (z_xml_element
                               ,'/goods'
                               ,'dangerGoods'
                               ,z_xml_danger);
            END IF;

            --package
            FOR pack IN (SELECT c002 code, c004 amount, c005 description, c006 larged_packets_amount
                           FROM apex_collections
                          WHERE     collection_name = smgs2_interface.packages_coll_name
                                AND c001 = goods.unique_key)
            LOOP
                l_step :=
                    'FOR goods.unique_key '
                    || goods.unique_key
                    || ' and pack.code '
                    || pack.code;
                z_xml_pack :=
                    xmltype ('<package>'
                             || dbms_xmlgen.convert (pack.description)
                             || '</package>');
                insert_attribute (z_xml_pack
                                 ,p_path      => '/package'
                                 ,p_attr_name => 'code'
                                 ,p_attr_val  => pack.code
                                 ,p_mandatory => TRUE);

                IF pack.larged_packets_amount > 0
                THEN
                    insert_attribute (z_xml_pack
                                     ,p_path      => '/package'
                                     ,p_attr_name => 'amount'
                                     ,p_attr_val  => pack.amount
                                                    || '/'
                                                    || pack.larged_packets_amount
                                     ,p_mandatory => TRUE);
                ELSE
                    insert_attribute (z_xml_pack
                                     ,p_path      => '/package'
                                     ,p_attr_name => 'amount'
                                     ,p_attr_val  => pack.amount
                                     ,p_mandatory => TRUE);
                END IF;

                insert_element (z_xml_element
                               ,'/goods'
                               ,'package'
                               ,z_xml_pack);
            END LOOP;

            --labels
            FOR lbl IN (SELECT c002 owner, c003 lbl
                          FROM apex_collections
                         WHERE     collection_name = smgs2_interface.packages_coll_name
                               AND c001 = goods.unique_key)
            LOOP
                l_step :=
                    'FOR goods.unique_key '
                    || goods.unique_key
                    || ' and lbl.lbl '
                    || lbl.lbl;
                z_xml_label :=
                    xmltype ('<label>'
                             || dbms_xmlgen.convert (lbl.lbl)
                             || '</label>');
                insert_attribute (z_xml_label
                                 ,p_path      => '/label'
                                 ,p_attr_name => 'owner'
                                 ,p_attr_val  => nvl (lbl.owner, 'CZ')
                                 ,p_mandatory => TRUE);
            END LOOP;

            l_step        :=
                'FOR goods.unique_key '
                || goods.unique_key
                || ' and weight';
            --weightClient
            insert_element (z_xml_element
                           ,'/goods'
                           ,'weightClient'
                           ,xmltype ('<weightClient>'
                                     || goods.client_weight
                                     || '</weightClient>'));
            --weightRailway
            insert_element (z_xml_element
                           ,'/goods'
                           ,'weightRailway'
                           ,xmltype ('<weightRailway>'
                                     || goods.railway_weight
                                     || '</weightRailway>'));

            insert_element (p_xml
                           ,'/waybill'
                           ,'goods'
                           ,z_xml_element);
        END LOOP;

        -- wagons
        FOR wagon IN (  SELECT c001       w_number
                              ,c002       rw_admin
                              ,c003       net_weight
                              ,c004       capacity
                              ,c005       axis
                              ,c006       goods_weight
                              ,seq_id     position
                              ,c009       kalibr_code
                              ,c010       owner_name
                              ,c011       provider
                              ,c012       prev_etsng
                              ,c013       prev_gng
                              ,c050       unique_key
                              ,seq_id
                          FROM apex_collections
                         WHERE collection_name = smgs2_interface.wagons_coll_name
                      ORDER BY seq_id)
        LOOP
            l_step      :=
                'FOR wagon.position '
                || wagon.position;
            z_xml_wagon := xmltype ('<wagon></wagon>');
            insert_attribute (z_xml_wagon
                             ,p_path      => '/wagon'
                             ,p_attr_name => 'position'
                             ,p_attr_val  => wagon.position
                             ,p_mandatory => TRUE);
            insert_attribute (z_xml_wagon
                             ,p_path      => '/wagon'
                             ,p_attr_name => 'number'
                             ,p_attr_val  => wagon.w_number
                             ,p_mandatory => TRUE);
            insert_attribute (z_xml_wagon
                             ,p_path      => '/wagon'
                             ,p_attr_name => 'capacity'
                             ,p_attr_val  => wagon.capacity
                             ,p_mandatory => TRUE);
            insert_attribute (z_xml_wagon
                             ,p_path      => '/wagon'
                             ,p_attr_name => 'tareWeight'
                             ,p_attr_val  => wagon.net_weight
                             ,p_mandatory => TRUE);

            insert_attribute (z_xml_wagon
                             ,p_path      => '/wagon'
                             ,p_attr_name => 'axis'
                             ,p_attr_val  => wagon.axis
                             ,p_mandatory => TRUE);
            insert_attribute (z_xml_wagon
                             ,p_path      => '/wagon'
                             ,p_attr_name => 'wagonProvider'
                             ,p_attr_val  => wagon.provider
                             ,p_mandatory => FALSE);
            insert_attribute (z_xml_wagon
                             ,p_path      => '/wagon'
                             ,p_attr_name => 'ownerInformation'
                             ,p_attr_val  => wagon.owner_name
                             ,p_mandatory => FALSE);
            insert_attribute (z_xml_wagon
                             ,p_path      => '/wagon'
                             ,p_attr_name => 'tankCaliber'
                             ,p_attr_val  => wagon.kalibr_code
                             ,p_mandatory => FALSE);

            insert_element (z_xml_wagon
                           ,'/wagon'
                           ,'goodsWeight'
                           ,xmltype ('<goodsWeight>'
                                     || wagon.goods_weight
                                     || '</goodsWeight>'));

            -- wagon leads
            FOR lead IN (SELECT c001 w_number, c002 lead_number, c003 owner, c004 amount, c005 station
                           FROM apex_collections
                          WHERE     collection_name = smgs2_interface.wagon_leads_coll_name
                                AND c001 = wagon.w_number)
            LOOP
                l_step     :=
                    'FOR wagon.position '
                    || wagon.position
                    || ' and LEAD.lead_number '
                    || lead.lead_number;
                z_xml_lead := xmltype ('<lead></lead>');
                insert_attribute (z_xml_lead
                                 ,p_path      => '/lead'
                                 ,p_attr_name => 'amount'
                                 ,p_attr_val  => lead.amount
                                 ,p_mandatory => TRUE);
                insert_attribute (z_xml_lead
                                 ,p_path      => '/lead'
                                 ,p_attr_name => 'owner'
                                 ,p_attr_val  => lead.owner
                                 ,p_mandatory => TRUE);
                insert_attribute (z_xml_lead
                                 ,p_path      => '/lead'
                                 ,p_attr_name => 'station'
                                 ,p_attr_val  => lead.station
                                 ,p_mandatory => FALSE);
                insert_element (z_xml_lead
                               ,'/lead'
                               ,'sign'
                               ,xmltype ('<sign>'
                                         || dbms_xmlgen.convert (lead.lead_number)
                                         || '</sign>'));

                insert_element (z_xml_wagon
                               ,'/wagon'
                               ,'lead'
                               ,z_xml_lead);
            END LOOP;

            -- containers
            FOR cont
                IN (SELECT seq_id     position
                          ,c001       w_number
                          ,c003       container_number
                          ,c004       rwadmin
                          ,c005       net_weight
                          ,c006       container_type
                          ,c007       weight
                          ,c008       ownership_form
                      FROM apex_collections
                     WHERE collection_name = smgs2_interface.containers_coll_name)
            LOOP
                l_step          :=
                    'FOR wagon.position '
                    || wagon.position
                    || ' and cont.position '
                    || cont.position;
                z_xml_container := xmltype ('<equipment></equipment>');
                insert_attribute (z_xml_container
                                 ,p_path      => '/equipment'
                                 ,p_attr_name => 'position'
                                 ,p_attr_val  => cont.position
                                 ,p_mandatory => TRUE);

                insert_attribute (z_xml_container
                                 ,p_path      => '/equipment'
                                 ,p_attr_name => 'ownershipType'
                                 ,p_attr_val  => cont.ownership_form
                                 ,p_mandatory => TRUE);

                insert_attribute (z_xml_container
                                 ,p_path      => '/equipment'
                                 ,p_attr_name => 'country'
                                 ,p_attr_val  => cont.rwadmin
                                 ,p_mandatory => TRUE);

                insert_attribute (z_xml_container
                                 ,p_path      => '/equipment'
                                 ,p_attr_name => 'number'
                                 ,p_attr_val  => cont.container_number
                                 ,p_mandatory => TRUE);

                insert_attribute (z_xml_container
                                 ,p_path      => '/equipment'
                                 ,p_attr_name => 'tareWeight'
                                 ,p_attr_val  => cont.net_weight
                                 ,p_mandatory => TRUE);
                insert_element (z_xml_container
                               ,'/equipment'
                               ,'type'
                               ,xmltype ('<type><containerType sizeCode="'
                                         || cont.container_type
                                         || '"></containerType></type>'));

                -- container leads
                FOR lead IN (SELECT c001 container_number, c002 lead_number, c003 owner, c004 amount, c005 station
                               FROM apex_collections
                              WHERE     collection_name = smgs2_interface.container_leads_coll_name
                                    AND c001 = cont.container_number)
                LOOP
                    l_step     :=
                        'FOR wagon.position '
                        || wagon.position
                        || ' and cont.position '
                        || cont.position
                        || ' and LEAD.lead_number '
                        || lead.lead_number;
                    z_xml_lead := xmltype ('<lead></lead>');
                    insert_attribute (z_xml_lead
                                     ,p_path      => '/lead'
                                     ,p_attr_name => 'amount'
                                     ,p_attr_val  => lead.amount
                                     ,p_mandatory => TRUE);
                    insert_attribute (z_xml_lead
                                     ,p_path      => '/lead'
                                     ,p_attr_name => 'owner'
                                     ,p_attr_val  => lead.owner
                                     ,p_mandatory => TRUE);
                    insert_attribute (z_xml_lead
                                     ,p_path      => '/lead'
                                     ,p_attr_name => 'station'
                                     ,p_attr_val  => lead.station
                                     ,p_mandatory => FALSE);
                    insert_element (z_xml_lead
                                   ,'/lead'
                                   ,'sign'
                                   ,xmltype ('<sign>'
                                             || dbms_xmlgen.convert (lead.lead_number)
                                             || '</sign>'));

                    insert_element (z_xml_container
                                   ,'/equipment'
                                   ,'lead'
                                   ,z_xml_lead);
                END LOOP;

                l_step          :=
                    'FOR wagon.position '
                    || wagon.position
                    || ' and cont.position '
                    || cont.position
                    || ' and after loop LEAD';
                insert_element (z_xml_container
                               ,'/equipment'
                               ,'goodsWeight'
                               ,xmltype ('<goodsWeight>'
                                         || cont.weight
                                         || '</goodsWeight>'));

                insert_element (z_xml_wagon
                               ,'/wagon'
                               ,'equipment'
                               ,z_xml_container);
            END LOOP;

            l_step      :=
                'FOR wagon.position '
                || wagon.position
                || ' and after loop cont';

            IF    wagon.prev_etsng IS NOT NULL
               OR wagon.prev_gng IS NOT NULL
            THEN
                insert_element (z_xml_wagon
                               ,'/wagon'
                               ,'previousGoods'
                               ,xmltype ('<previousGoods gngCode="'
                                         || wagon.prev_gng
                                         || '" etsngCode="'
                                         || wagon.prev_etsng
                                         || '"></previousGoods>'));
            END IF;

            insert_element (p_xml
                           ,'/waybill'
                           ,'wagon'
                           ,z_xml_wagon);
        END LOOP;

        -- texts
        FOR txt IN (SELECT c002 smgs_role, c001 value
                      FROM apex_collections
                     WHERE collection_name = smgs2_interface.texts_coll_name)
        LOOP
            l_step :=
                'insert_element FOR txt.smgs_role '
                || txt.smgs_role;
            insert_element (p_xml
                           ,'/waybill'
                           ,'text'
                           ,xmltype ('<text role="'
                                     || txt.smgs_role
                                     || '">'
                                     || dbms_xmlgen.convert (txt.value)
                                     || '</text>'));
        END LOOP;

        --documentAdded
        FOR participant IN (  SELECT seq_id
                                    ,c003                  smgs_role
                                    ,c016                  first_station_code
                                    ,c017                  first_station_name
                                    ,c018                  last_station_code
                                    ,c019                  last_station_name
                                    ,rt1.raudtadm_kood     first_station_rwadmin
                                    ,rt2.raudtadm_kood     last_station_rwadmin
                                    ,r1.lyhend             first_station_state
                                    ,r2.lyhend             last_station_state
                                FROM apex_collections
                                    ,jaamad                   edj1
                                    ,jaamad                   edj2
                                    ,raudteed                 rt1
                                    ,raudteed                 rt2
                                    ,raudteeadministratsioonid ra1
                                    ,raudteeadministratsioonid ra2
                                    ,riigid                   r1
                                    ,riigid                   r2
                               WHERE     collection_name = smgs2_interface.participants_coll_name
                                     AND c016 = edj1.kood6(+)
                                     AND c018 = edj2.kood6(+)
                                     AND edj1.raudtee_kood = rt1.kood(+)
                                     AND edj2.raudtee_kood = rt2.kood(+)
                                     AND rt1.raudtadm_kood = ra1.kood(+)
                                     AND rt2.raudtadm_kood = ra2.kood(+)
                                     AND ra1.riik_riik_id = r1.riik_id(+)
                                     AND ra2.riik_riik_id = r2.riik_id(+)
                            ORDER BY decode (c003,  'CN', 0,  'CZ', 1,  'GS', 2,  'DCP', 3,  'CPD', 4,  'CA', 5,  6)
                                    ,seq_id)
        LOOP
            l_step            :=
                'FOR participant.seq_id '
                || participant.seq_id;
            z_xml_participant := NULL;

            IF participant.smgs_role = 'CN'
            THEN
                /*Receiver*/
                z_xml_participant :=
                    add_participant ('receiver'
                                    ,participant.seq_id);
                insert_element (p_xml
                               ,'/waybill'
                               ,'receiver'
                               ,z_xml_participant);
            ELSIF participant.smgs_role = 'CZ'
            THEN
                /*Sender*/
                z_xml_participant :=
                    add_participant ('sender'
                                    ,participant.seq_id);
                insert_element (p_xml
                               ,'/waybill'
                               ,'sender'
                               ,z_xml_participant);
            ELSIF participant.smgs_role = 'GS'
            THEN
                /*Payer*/
                z_xml_participant :=
                    add_participant ('payer'
                                    ,participant.seq_id);
                insert_element (p_xml
                               ,'/waybill'
                               ,'payer'
                               ,z_xml_participant);
            ELSIF participant.smgs_role = 'DCP'
            THEN
                /*PayerAtDispatch*/
                z_xml_participant :=
                    add_participant ('payerAtDispatch'
                                    ,participant.seq_id);
                insert_element (p_xml
                               ,'/waybill'
                               ,'payerAtDispatch'
                               ,z_xml_participant);
            ELSIF participant.smgs_role = 'CPD'
            THEN
                /*PayerAtDestination*/
                z_xml_participant :=
                    add_participant ('payerAtDestination'
                                    ,participant.seq_id);
                insert_element (p_xml
                               ,'/waybill'
                               ,'payerAtDestination'
                               ,z_xml_participant);
            ELSIF participant.smgs_role = 'CA'
            THEN
                /*undertaker*/
                z_xml_participant :=
                    add_participant ('undertakerData'
                                    ,participant.seq_id);

                z_xml_undertacker := xmltype ('<undertaker></undertaker>');
                insert_element (z_xml_undertacker
                               ,'/undertaker'
                               ,'undertakerData'
                               ,z_xml_participant);
                z_xml_station     :=
                    add_station ('stationFrom'
                                ,participant.first_station_code
                                ,participant.first_station_name
                                ,participant.first_station_state
                                ,participant.first_station_rwadmin);
                insert_element (z_xml_undertacker
                               ,'/undertaker'
                               ,'stationFrom'
                               ,z_xml_station);
                z_xml_station     :=
                    add_station ('stationTo'
                                ,participant.last_station_code
                                ,participant.last_station_name
                                ,participant.last_station_state
                                ,participant.first_station_rwadmin);
                insert_element (z_xml_undertacker
                               ,'/undertaker'
                               ,'stationTo'
                               ,z_xml_station);
                insert_element (p_xml
                               ,'/waybill'
                               ,'undertaker'
                               ,z_xml_undertacker);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_params := logger_service.logger.gc_empty_tab_param;
            logger_service.logger.append_param (l_params
                                               ,'l_step'
                                               ,l_step);
            logger_service.logger.log_error (p_text   => sqlerrm
                                            ,p_scope  => 'spv.'
                                                        || $$plsql_unit
                                                        || '.collections_to_xml'
                                            ,p_params => l_params);
    END collections_to_xml;
END smgs2_validate;
/
