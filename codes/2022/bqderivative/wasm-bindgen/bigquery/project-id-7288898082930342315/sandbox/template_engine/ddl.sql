CREATE OR REPLACE PROCEDURE `project-id-7288898082930342315`.sandbox.template_engine(target STRUCT<table_catalog STRING, table_schema STRING, table_name STRING>, placeholders ARRAY<STRUCT<identifier STRING, new_identifier STRING>>, OUT generated_sql STRING)
begin 
    execute immediate format("""
      create or replace `input_view_information_schema`
      as
        select  
          view_definition
          , @placeholders as placeholders
        from
          `%s.INFORMATION_SCHEMA.VIEWS`
        where
          table_name = "%s"
      """
      , target.table_schema
      , target.table_name
    )
    using placeholders as placeholders 
    ;
end