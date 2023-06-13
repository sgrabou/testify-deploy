-- This sql script will delete all data in the target schema except in the "type" tables in in the flyway table.
do
$$
    declare
l_stmt text;
begin
select 'truncate ' || string_agg(format('%I.%I', schemaname, tablename), ',')
into l_stmt
from testify.pg_catalog.pg_tables
where schemaname in ('SCHEMA_NAME')
  AND tablename NOT LIKE '%type'
  AND tablename NOT LIKE 'flyway%';

execute l_stmt;
end;
$$
