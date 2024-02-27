# MSSQL_to_postgresql
This post is about how to migrate the MSSQL database to postgresql for the deep security manager (DSM)

## Background
I'm not a database administrator. However, the DSM's repository will be end of support.
I tried to migrate the DSM repository from MSSQL 2017 to postgresql 14.10 to continue the on-going maintenance.

## Consideration
The migration for MSSQL is not any new issues. Plenty of suggestions can be found by search engine.
* The popular suggestion is using MS SQL Server Management Studio to export the data through psqlodbc drive for both schema and data in once.
* Another suggestion is manually handling the schema structure and data by customized sql statement mentioned in below URL.
  * https://wiki.postgresql.org/wiki/Microsoft_SQL_Server_to_PostgreSQL_Migration_by_Ian_Harding

To simplify the migration process, MS SQL Server Management Studio seems an easy solution.
* After doing the migration testing, customize the sql statement is still required. So that, the exported data can fit into the new table in postgresql.

  <img src="https://github.com/newbieAC/MSSQL_to_postgresql/blob/main/screen/MSSQL_customize_create_tbl_sql.jpg" width="400" height="400">

* Also, the MSSQL study may has an error if exporting huge table.

  <img src="https://github.com/newbieAC/MSSQL_to_postgresql/blob/main/screen/MSSQL_memory_issue.jpg" width="400" height="400">

Therefore, manually compiling sql statements is mandatory in either solutions. To speed up the process, I have done below activites to minimize the manually processes.
* Installed the DSM with postgresql 14.10 on temporary server
* Dump the database / schema structure to sql from postgresql on temporary server
  * This approach can skip the manual handling effort for the database's tables
* Install the postgresql on target database server
* Create the database / schema by dumped sql on target database server
* Write a script to generate the export data MSSQL sql statements based on the dumped sql information to:-
  * Select columns based on the sequence of the target table
  * Handle the null data, data format of each datatype
  * Handle the error of specified table by replacing special characters of theirs
  * This approach can minimize the manual work for the data
* Use the generated sql statements to export the data by table
* Import the data to posgresql directly
* Count the data in MSSQL and postgresql by table


## Migration procedures
### Installed the DSM with postgresql 14.10 on temporary server
For the DSM insatllation with postgresql, please refers below URL.
* Configuration database
  * https://help.deepsecurity.trendmicro.com/20_0/on-premise/database-configure.html
* Install DSM
  * https://help.deepsecurity.trendmicro.com/20_0/on-premise/manager-install.html#Run

### Dump the database / schema structure to sql from postgresql on temporary server
To backup / dump the database structure to sql statement, pg_dump utility will be used:
* pg_dump --schema-only -U \<user\> -d \<DB\> -n \<schema\> \> outputfile.sql
*   example
    ```
    pg_dump --schema-only -U postgres -d dsmDB -n public > postgresql_db_dump.txt
    ```
  * This approach can skip the manual handling effort for the database's tables

### Install the postgresql on target database server
After completing the installation of postgresql, Please configure the database based on the DSM recommendation.
* Configuration database
  * https://help.deepsecurity.trendmicro.com/20_0/on-premise/database-configure.html

### Create the database / schema by dumped sql statement on target database server
To create the database by dumped sql statement, psql utility will be used:
* psql -U \<user\> -d \<DB\> \< inputfile.sql
*   example
    ```
    psql -U postgres -d dsmDB < postgresql_db_dump.sql
    ```

### Write a script to generate the export data MSSQL sql statements based on the dumped sql information to:-
1.  Post task: Extract the create table statement for each table
    ```
    mkdir create_sql
    grep "^CREATE TABLE" postgresql_db_dump_create_tbl.sql | grep [[:print:]] | awk '{ print $2, $3 }' | sed 's/[()]//g' | while read type tbl_name
    do
    echo "sed -E '/^CREATE $type $tbl_name /,\$!d' postgresql_db_dump.txt  | sed -E '/^\)/q' | tee ./create_sql/${type}_${tbl_name}.txt"
    done | sh
    ```

2. Write the script to generate the command for dump the table data only on MSSQL. The script should:-
  * Based on the columns order of the target table to select data;
  * Based on the datatype to handle the null data for each column;
  * Based on the datatype to handle the output format; and
    * timestamp output format `yyyy-MM-dd HH:mm:ss.fff`
    * date output format `yyyy-MM-dd`      
  * Based on the import data error message to handle the related special charaters for each table. So that, the data conversion time can be minimized.
    | character | MSSQL | Postgresql |
    | -------------  | ------------- | ------------- |
    |line feed|char(10) |'\n'|
    |carriage return|char(13)|'\r'|
    |Horizontal Tab|char(9)|'  '|
    |backslash|'\\'|'\\\\'|
    
  * This approach can minimize the manual work for handling the datatype format

  *   Below is the [gen_mssql_bcp.sh](gen_mssql_bcp.sh) usage to generate the bcp command by table.
    
      ```
      $ ./gen_mssql_bcp.sh
      ./gen_sql.sh <table_name>
      ```

      ```
      $ ./gen_mssql_bcp.sh virtualhostmetadatas
      echo "table virtualhostmetadatas"
      bcp "select virtualhostmetadataid, ISNULL(convert(varchar,hostid), '\N') as hostidss, replace(NULLIF(convert(nvarchar(MAX),originalvirtualuuid),          ''), '\', '\\') as originalvirtualuuidss from virtualhostmetadatas" queryout virtualhostmetadatas.csv -S localhost -T -t"\t" -c -C 65001
      ```

### Use the generated sql statements to export the data by table
 * As the [maximum command length of windows command prompt](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/command-line-string-limitation) is limited to 8191 characters, windows powershell will be used to execute the bcp command. [bcp_data_exports_by_tbl.ps1](bcp_data_exports_by_tbl.ps1) is the sample powershell scirpt for references.
 * Reminder open the powershell as administrator

   <img src="https://github.com/newbieAC/MSSQL_to_postgresql/blob/main/screen/run_powershell_as_admin.jpg" width="400">

 * Run the powershell script
   
   <img src="https://github.com/newbieAC/MSSQL_to_postgresql/blob/main/screen/MSSQL_export.jpg" width="600">
   
 * check any error message and `copy out failed` message in `bcp_export_by_tbl.log`. Fix all export data error before move to next step.

   <img src="https://github.com/newbieAC/MSSQL_to_postgresql/blob/main/screen/MSSQL_copy_out_failed_msg.jpg" width="600">

### Import the data to posgresql directly
*   To handle WIN-1252 characters for table entitys, vulnerabilities and detectionrules. `SET CLIENT_ENCODING TO 'utf8'` has be used before import the tables data. [postgresql_data_imports_by_tbl.sql](postgresql_data_imports_by_tbl.sql) is the sample sql for references
    
    ```
    SHOW client_encoding;
    SET CLIENT_ENCODING TO 'utf8';
     
    select 'copy ' || 'entitys' as action;
    copy entitys FROM 'D:\Backup\flatfile\entitys.csv';
    select 'copy ' || 'vulnerabilities' as action;
    copy vulnerabilities FROM 'D:\Backup\flatfile\vulnerabilities.csv';
    select 'copy ' || 'detectionrules' as action;
    copy detectionrules FROM 'D:\Backup\flatfile\detectionrules.csv';
    ```
* Opne the command prompt as administrators

  <img src="https://github.com/newbieAC/MSSQL_to_postgresql/blob/main/screen/run_command_prompt_as_administrator.jpg" width="400">
      
*   Run the import sql under the bin folder of the postgresql installed directory

    ```
    psql.exe -U postgres -d dsmDB < D:\Backup\flatfile\postgresql_data_imports_by_tbl.sql
    ```

    <img src="https://github.com/newbieAC/MSSQL_to_postgresql/blob/main/screen/postgresql_data_import.jpg" width="600">

  
### Count the data in MSSQL and postgresql by table
*   To count the number of rows by table in MSSQL. I have refers the suggestion in [How to get the size of all tables in SQL Server Database](https://misterflutter.medium.com/how-to-get-the-size-of-all-tables-in-sql-server-database-c1588513ef01)
    ```
    SELECT 
        t.name AS TableName,
        s.name AS SchemaName,
        p.rows,
        SUM(a.total_pages) * 8 AS TotalSpaceKB, 
        CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB,
        SUM(a.used_pages) * 8 AS UsedSpaceKB, 
        CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB, 
        (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB,
        CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
    FROM 
        sys.tables t
    INNER JOIN      
        sys.indexes i ON t.object_id = i.object_id
    INNER JOIN 
        sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN 
        sys.allocation_units a ON p.partition_id = a.container_id
    LEFT OUTER JOIN 
        sys.schemas s ON t.schema_id = s.schema_id
    WHERE 
        t.name NOT LIKE 'dt%' 
        AND t.is_ms_shipped = 0
        AND i.object_id > 255 
    GROUP BY 
        t.name, s.name, p.rows
    ORDER BY 
        TotalSpaceMB DESC, t.name
    ```
*   To count the number of row for each tables in postgresql. I have refers the suggestion in (https://gist.github.com/amccartney/902f386a2f419e4e84d349ae5be0d069)[https://gist.github.com/amccartney/902f386a2f419e4e84d349ae5be0d069]
    ```
    SELECT schemaname,relname,n_live_tup
    FROM pg_stat_user_tables
    ORDER BY n_live_tup DESC;
    ```

* Make sure the number of rows are same in all tables.
 
## Finalize actions
* Stop the MSSQL service
* Change the postgresql to use the service port of MSSQL
*   update the DSM with propoer configuration to access the postgresql database
    ```
    #
    #Wed Dec 06 11:42:50 CST 2023
    manager.online.help.version=20.0.9400
    database.SqlServer.user=dsmConnector
    database.name=dsm
    install.latestSecurityUpdateFilename=C\:\\Program Files\\Trend Micro\\Deep Security Manager\\installfiles\\latest.dsru
    install.overridePrecheckListFilename=C\:\\Program Files\\Trend Micro\\Deep Security Manager\\installfiles\\prechecker_list.override.json
    default.locale=en_US
    install.securityProfilesFilename=C\:\\Program Files\\Trend Micro\\Deep Security Manager\\installfiles\\SecurityProfiles.xml
    database.SqlServer.driver=MSJDBC
    install.precheckListFilename=C\:\\Program Files\\Trend Micro\\Deep Security Manager\\installfiles\\prechecker_list.json
    install.latestSecurityUpdateMapFilename=C\:\\Program Files\\Trend Micro\\Deep Security Manager\\installfiles\\latest_dsru_map.csv
    database.SqlServer.password=<admin password>
    database.type=SqlServer
    install.contentStringsFilename=C\:\\Program Files\\Trend Micro\\Deep Security Manager\\installfiles\\ContentStrings.properties
    database.SqlServer.server=<server name / server IP>
    manager.managerNodeGUID=0F4798FB-B3AC-FF57-8A1C-86B36DD331D4

    ```
* Test the DSM service and verify the configuration

