create or replace package uc_ai_data
  authid definer
as

  /**
   * UC AI Data Tools — HR Schema
   * Functions exposed as AI tools over the HR sample dataset.
   * All functions accept a JSON_OBJECT_T (bound as :parameters) and return CLOB.
   */

  /*
   * Search employees by name, department, or job.
   * Parameters: p_name (optional), p_department_id (optional), p_job_id (optional)
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
   * Get the reporting hierarchy (manager chain) for an employee.
   * Parameters: p_employee_id (required)
   */
  function get_employee_hierarchy (p_parameters in clob) return clob;

end uc_ai_data;
/
