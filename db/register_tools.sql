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
  -- 1. search_employees
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Search Employees",
    "description": "Search HR employees by name, department ID, or job ID. All parameters are optional.",
    "properties": {
      "p_name":          {"type":"string",  "description":"Full or partial employee name (case-insensitive)"},
      "p_department_id": {"type":"number",  "description":"Filter by department ID"},
      "p_job_id":        {"type":"string",  "description":"Filter by job code, e.g. IT_PROG or SA_MAN"}
    },
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_SEARCH_EMPLOYEES',
    p_description => 'Search HR employees by name, department, or job. Returns employee list with job title, salary, and department.',
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
    "description": "Get full details of an employee including manager, office location, and job history. Provide either p_employee_id or p_last_name.",
    "properties": {
      "p_employee_id": {"type":"number", "description":"Numeric employee ID"},
      "p_last_name":   {"type":"string", "description":"Employee last name (partial match, case-insensitive)"}
    },
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_GET_EMPLOYEE_DETAILS',
    p_description => 'Get complete employee profile: job, salary, manager, office city, country.',
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
    "description": "List all company departments with manager name, office location, and headcount.",
    "properties": {},
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_GET_DEPARTMENTS',
    p_description => 'List all departments with manager, city, country, and employee headcount.',
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
      "p_department_id": {"type":"number", "description":"Optional: filter to a specific department ID"}
    },
    "required": []
  }');
  upsert_tool(
    p_code        => 'HR_GET_SALARY_REPORT',
    p_description => 'Get salary statistics per department: headcount, average, min, max, and total payroll.',
    p_call        => 'return uc_ai_data.get_salary_report(:parameters);',
    p_schema      => l_schema
  );

  -- -----------------------------------------------------------------------
  -- 6. get_employee_hierarchy
  -- -----------------------------------------------------------------------
  l_schema := json_object_t.parse('{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "title": "Get Employee Hierarchy",
    "description": "Walk the management chain upward from an employee to find all their managers up to the top.",
    "properties": {
      "p_employee_id": {"type":"number", "description":"Employee ID to start the hierarchy walk from (required)"}
    },
    "required": ["p_employee_id"]
  }');
  upsert_tool(
    p_code        => 'HR_GET_EMPLOYEE_HIERARCHY',
    p_description => 'Trace the reporting chain (hierarchy) from a specific employee upward through all managers.',
    p_call        => 'return uc_ai_data.get_employee_hierarchy(:parameters);',
    p_schema      => l_schema
  );

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('All HR tools registered successfully.');

END;
/
