-- Register UC AI Data Tools for HR Schema
-- Run as TEST user after uc_ai_data package is installed.

SET DEFINE OFF
SET SERVEROUTPUT ON

DECLARE
  l_schema  json_object_t;
  l_tool_id uc_ai_tools.id%type;

  -- Helper: upsert a tool (create or replace)
  procedure upsert_tool(
    p_code        in varchar2,
    p_description in varchar2,
    p_call        in varchar2,
    p_schema      in json_object_t
  ) as
  begin
    l_tool_id := uc_ai_tools_api.merge_tool_from_schema(
      p_tool_code    => p_code,
      p_description  => p_description,
      p_function_call => p_call,
      p_json_schema  => p_schema,
      p_tags         => apex_t_varchar2('hr', 'uc_ai_data')
    );
    dbms_output.put_line('Registered tool: ' || p_code || ' (id=' || l_tool_id || ')');
  end;

BEGIN

  -- -----------------------------------------------------------------------
  -- 1. search_employees  (updated with sort/limit/salary filters)
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Search Employees",
    "description": "Search HR employees. Supports filtering by name, department, job, salary range. Use p_order_by=SALARY_DESC + p_max_rows=1 to find the highest-paid employee.",
    "properties": {
      "p_name":          {"type":"string",  "description":"Full or partial employee name (case-insensitive)"},
      "p_department_id": {"type":"number",  "description":"Filter by department ID. Use HR_GET_DEPARTMENTS first to find department IDs for a specific country or region."},
      "p_job_id":        {"type":"string",  "description":"Filter by job code, e.g. IT_PROG or SA_MAN"},
      "p_min_salary":    {"type":"number",  "description":"Minimum salary filter"},
      "p_max_salary":    {"type":"number",  "description":"Maximum salary filter"},
      "p_order_by":      {"type":"string",  "description":"Sort order: SALARY_DESC, SALARY_ASC, NAME_ASC, NAME_DESC, HIRE_DATE_DESC, HIRE_DATE_ASC. Default: NAME_ASC"},
      "p_max_rows":      {"type":"number",  "description":"Limit number of results returned, e.g. 1 for top result, 5 for top 5"}
    },
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_SEARCH_EMPLOYEES',
    p_description => 'Search HR employees by name, department, job, or salary range. Supports sorting (SALARY_DESC/ASC, NAME_ASC/DESC, HIRE_DATE_DESC/ASC) and limiting rows. Use p_order_by=SALARY_DESC and p_max_rows=1 to find the highest-paid employee. To filter by country, first call HR_GET_DEPARTMENTS to get the department IDs for that country, then call this tool with p_department_id.',
    p_call        => 'return uc_ai_data.search_employees(:parameters);',
    p_schema      => l_schema
  );

  -- -----------------------------------------------------------------------
  -- 2. get_employee_details
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Get Employee Details",
    "description": "Get full details of an employee including manager, office location, country, and region. Provide either p_employee_id or p_last_name.",
    "properties": {
      "p_employee_id": {"type":"number", "description":"Numeric employee ID"},
      "p_last_name":   {"type":"string", "description":"Employee last name (partial match, case-insensitive)"}
    },
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_GET_EMPLOYEE_DETAILS',
    p_description => 'Get complete employee profile: job, salary, manager, office city, country, and region.',
    p_call        => 'return uc_ai_data.get_employee_details(:parameters);',
    p_schema      => l_schema
  );

  -- -----------------------------------------------------------------------
  -- 3. get_departments
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Get Departments",
    "description": "List all company departments with manager name, office location, country, region, and headcount.",
    "properties": {},
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_GET_DEPARTMENTS',
    p_description => 'List all departments with manager, city, country, region, and employee headcount.',
    p_call        => 'return uc_ai_data.get_departments(:parameters);',
    p_schema      => l_schema
  );

  -- -----------------------------------------------------------------------
  -- 4. get_jobs
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Get Jobs",
    "description": "List all job titles with their salary band and current headcount.",
    "properties": {},
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_GET_JOBS',
    p_description => 'List all job positions with min/max salary range and how many employees currently hold each role.',
    p_call        => 'return uc_ai_data.get_jobs(:parameters);',
    p_schema      => l_schema
  );

  -- -----------------------------------------------------------------------
  -- 5. get_salary_report
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Get Salary Report",
    "description": "Get salary statistics (average, min, max, total) grouped by department. Optionally filter by a single department.",
    "properties": {
      "p_department_id": {"type":"number", "description":"Optional: filter to a specific department ID. To get salary stats for a country, first call HR_GET_DEPARTMENTS to find department IDs in that country, then call this tool for each department."}
    },
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_GET_SALARY_REPORT',
    p_description => 'Get salary statistics per department: headcount, average, min, max, and total payroll. To get salary data for a specific country or region, first call HR_GET_DEPARTMENTS to find the department IDs in that country, then call this tool for each department ID and sum the total_salary values.',
    p_call        => 'return uc_ai_data.get_salary_report(:parameters);',
    p_schema      => l_schema
  );

  -- -----------------------------------------------------------------------
  -- 6. get_employee_hierarchy  (updated: now supports UP and DOWN direction)
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Get Employee Hierarchy",
    "description": "Walk the organisational hierarchy. UP (default): trace managers from an employee up to the CEO. DOWN: find all direct and indirect subordinates of a manager recursively.",
    "properties": {
      "p_employee_id": {"type":"number", "description":"Employee or manager ID to start from (required)"},
      "p_direction":   {"type":"string", "description":"UP to find managers chain up to CEO; DOWN to find all subordinates recursively. Default: UP"}
    },
    "required": ["p_employee_id"]
  }');
  upsert_tool(
    p_code        => 'HR_GET_EMPLOYEE_HIERARCHY',
    p_description => 'Walk the org chart from any employee. Use p_direction=UP to find the full managers chain to CEO; use p_direction=DOWN to find all subordinates of a manager at every level.',
    p_call        => 'return uc_ai_data.get_employee_hierarchy(:parameters);',
    p_schema      => l_schema
  );

  -- -----------------------------------------------------------------------
  -- 7. get_job_history  (new)
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Get Job History",
    "description": "Get the employment history (past positions) for one or all employees. Shows previous jobs, departments, and tenure duration.",
    "properties": {
      "p_employee_id": {"type":"number", "description":"Employee ID. If omitted, returns job history for all employees."}
    },
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_GET_JOB_HISTORY',
    p_description => 'Get past job positions for an employee: previous job titles, departments, start/end dates, and duration in years.',
    p_call        => 'return uc_ai_data.get_job_history(:parameters);',
    p_schema      => l_schema
  );

  -- -----------------------------------------------------------------------
  -- 8. get_locations  (new)
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Get Locations",
    "description": "Get all company office locations with street address, city, state, postal code, country, and region. Filter by country or region.",
    "properties": {
      "p_country_id":  {"type":"string", "description":"Two-letter country code to filter locations, e.g. US, UK, DE"},
      "p_region_id":   {"type":"number", "description":"Region ID to filter locations (1=Europe, 2=Americas, 3=Asia, 4=Middle East and Africa)"}
    },
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_GET_LOCATIONS',
    p_description => 'Get all office locations with city, country, region, and department count. Filter by country code or region ID.',
    p_call        => 'return uc_ai_data.get_locations(:parameters);',
    p_schema      => l_schema
  );

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('All HR tools registered successfully.');

END;
/
