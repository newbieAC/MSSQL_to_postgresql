#!/bin/bash

if [ $# -ne 1 ] ; then
    echo "${0} <table_name>"
    exit 1
fi

tbl=$1
sqlFile=`ls create_sql/* | grep -i TABLE_public.${tbl}.txt`

if [ ! -z $sqlFile ] ; then

    col_suff='ss'

    sql=''

    while read col attribute
    do

    type=`echo $attribute | awk '{ print $1 }' | tr -d '\r'`

    if [ "$type" == "character" ] ; then



        if [ "$tbl" == "systemsettings" ] || [ "$tbl" == "payloadfilter2s" ] || [ "$tbl" == "dsmcredentials" ] || [ "$tbl" == "securityprofiles" ] || [ "$tbl" == "systemeventscache2" ] || [ "$tbl" == "scandirectorylists" ] || [ "$tbl" == "integrityrules" ] || [ "$tbl" == "hostcachehmdqueries" ] || [ "$tbl" == "actrustrules" ] || [ "$tbl" == "loginspectionrules" ] ; then
            sql="$sql, replace(replace(replace(NULLIF(convert(nvarchar(MAX),$col), ''), '\', '\\\\'), char(10), '\n'), char(13), '\r') as ${col}${col_suff}"

        elif [ "$tbl" == "systemevents" ] || [ "$tbl" == "detectionexpressions" ] || [ "$tbl" == "connectiontypes" ] || [ "$tbl" == "portlists" ] || [ "$tbl" == "scanfilelists" ] || [ "$tbl" == "payloadfilter2metadatas" ] || [ "$tbl" == "integrityrulemetadatas" ] ; then
            sql="$sql, replace(replace(replace(NULLIF(convert(nvarchar(MAX),$col), ''), '\', '\\\\'), char(10), '\n'), char(9), '\t') as ${col}${col_suff}"

        elif [ "$tbl" == "detectionrules" ] || [ "$tbl" == "vulnerabilities" ] ; then
            sql="$sql, replace(replace(replace(replace(replace(NULLIF(convert(nvarchar(MAX),$col), ''), '\', '\\\\'), char(10), '\n'), char(13), '\r'), char(9), '\t')COLLATE Latin1_General_BIN, nchar(0x9d) COLLATE Latin1_General_BIN, '') as ${col}${col_suff}"

        else
            sql="$sql, replace(NULLIF(convert(nvarchar(MAX),$col), ''), '\', '\\\\') as ${col}${col_suff}"
        fi


    elif [[ "$type" == "text"* ]] ; then

        if [ "$tbl" == "systemsettings" ] || [ "$tbl" == "payloadfilter2s" ] || [ "$tbl" == "dsmcredentials" ] || [ "$tbl" == "securityprofiles" ] || [ "$tbl" == "systemeventscache2" ] || [ "$tbl" == "scandirectorylists" ] || [ "$tbl" == "integrityrules" ] || [ "$tbl" == "hostcachehmdqueries" ] || [ "$tbl" == "actrustrules" ] || [ "$tbl" == "loginspectionrules" ] ; then
            sql="$sql, replace(replace(replace(NULLIF(convert(nvarchar(MAX),$col), ''), '\', '\\\\'), char(10), '\n'), char(13), '\r') as ${col}${col_suff}"

        elif [ "$tbl" == "systemevents" ] || [ "$tbl" == "detectionexpressions" ] || [ "$tbl" == "connectiontypes" ] || [ "$tbl" == "portlists" ] || [ "$tbl" == "scanfilelists" ] || [ "$tbl" == "payloadfilter2metadatas" ] || [ "$tbl" == "integrityrulemetadatas" ] ; then
            sql="$sql, replace(replace(replace(NULLIF(convert(nvarchar(MAX),$col), ''), '\', '\\\\'), char(10), '\n'), char(9), '\t') as ${col}${col_suff}"

        elif [ "$tbl" == "tlsservercredentials" ] || [ "$tbl" == "cacredentials" ] ; then
            sql="$sql, replace(replace(NULLIF(convert(nvarchar(MAX),$col), ''), char(10), '\n'), char(13), '\r') as ${col}${col_suff}"

        elif [ "$tbl" == "detectionrules" ] || [ "$tbl" == "vulnerabilities" ] ; then
            sql="$sql, replace(replace(replace(replace(replace(NULLIF(convert(nvarchar(MAX),$col), ''), '\', '\\\\'), char(10), '\n'), char(13), '\r'), char(9), '\t')COLLATE Latin1_General_BIN, nchar(0x9d) COLLATE Latin1_General_BIN, '') as ${col}${col_suff}"


        elif [ "$tbl" == "agentinstallersegments" ] ; then
            sql="$sql, NULLIF(convert(nvarchar(MAX),$col), '') as ${col}${col_suff}"
        else
            sql="$sql, replace(NULLIF(convert(nvarchar(MAX),$col), ''), '\', '\\\\') as ${col}${col_suff}"
        fi

    elif [[ "$type" == "timestamp"* ]] ; then
        sql="$sql, ISNULL(convert(varchar,format($col, 'yyyy-MM-dd HH:mm:ss.fff')), '\N') as ${col}${col_suff}"

    elif [[ "$type" == "date"* ]] ; then
        sql="$sql, ISNULL(convert(varchar,format($col, 'yyyy-MM-dd')), '\N') as ${col}${col_suff}"

    elif [[ "$type" == "integer"* ]] ; then
        sql="$sql, ISNULL(convert(varchar,$col), '\N') as ${col}${col_suff}"

    elif [[  "$attribute" != *"NOT NULL"* ]] ; then
        if [[ "$type" == "bigint"* ]] || [[ "$type" == "smallint"* ]] || [[ "$type" == "boolean"* ]] ; then
            sql="$sql, ISNULL(convert(varchar,$col), '\N') as ${col}${col_suff}"
        else
            sql="$sql, $col"
        fi
    else
        sql="$sql, $col"
    fi

    done <<< $( egrep -v "CREATE|;" $sqlFile | tr -d '\r' | sed 's/"//g' )

    echo echo \"table $tbl\"
    echo bcp \"select `echo $sql | sed 's/,//'` from $tbl\" queryout ${tbl}.csv -S localhost -T -t\"\\t\" -c -C 65001

else
    echo "Invalid table name."
    exit 1
fi
