create or replace package uc_ai_data
  authid definer
as

  /**
   * UC AI Data Tools — HR Schema
   * Functions exposed as AI tools over the HR sample dataset.
   * All functions accept a JSON_OBJECT_T (bound as :parameters) and return CLOB.
   */

  /*
   * Search employees by name, department, job, or salary range.
   * Parameters: p_name, p_department_id, p_job_id (all optional)
   *             p_min_salary, p_max_salary (optional salary filters)
   *             p_order_by: SALARY_DESC | SALARY_ASC | NAME_ASC | NAME_DESC | HIRE_DATE_DESC | HIRE_DATE_ASC
   *             p_max_rows: limit number of results (e.g. 1 for top earner)
   */
  function search_employees (p_parameters in clob) return clob;

  /*
   * Get full details of a single employee by employee_id or last_name.
   * Parameters: p_employee_id (optional), p_last_name (optional)
   */
  function get_employee_details (p_parameters in clob) return clob;

  /*
   * List all departments with their manager and location.
   * No required parameters.
   */
  function get_departments (p_parameters in clob) return clob;

  /*
   * List all job titles with salary range.
   * No required parameters.
   */
  function get_jobs (p_parameters in clob) return clob;

  /*
   * Get salary report grouped by department.
   * Parameters: p_department_id (optional – filter to single dept)
   */
  function get_salary_report (p_parameters in clob) return clob;

  /*
   * Get management hierarchy for an employee.
   * Parameters: p_employee_id (required)
   *             p_direction: UP (default – chain to CEO) | DOWN (all subordinates recursively)
   */
  function get_employee_hierarchy (p_parameters in clob) return clob;

  /*
   * Get job history (past positions) for an employee.
   * Parameters: p_employee_id (optional – all history if omitted)
   */
  function get_job_history (p_parameters in clob) return clob;

  /*
   * Get all office locations with country and region.
   * Parameters: p_country_id (optional), p_region_id (optional)
   */
  function get_locations (p_parameters in clob) return clob;

  /*
   * Render conversation history as HTML using HTP.P.
   * Called from the APEX PL/SQL Dynamic Content region.
   * p_messages_json: JSON array of {role, content} objects stored in session state.
   */
  procedure render_conversation (p_messages_json in clob);

  /*
   * Process a chatbot message: append user input, call UC AI with HR tools,
   * append AI response, update p_messages_json, and clear p_user_message.
   * Called via APEX invokeApi process.
   */
  procedure run_chatbot (
    p_user_message  in out nocopy varchar2,
    p_messages_json in out nocopy clob
  );

end uc_ai_data;
/
