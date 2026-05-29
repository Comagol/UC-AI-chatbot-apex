create or replace package body uc_ai_data as

  -- -------------------------------------------------------------------------
  -- search_employees
  -- -------------------------------------------------------------------------
  function search_employees (p_parameters in clob) return clob
  as
    l_json          json_object_t := json_object_t.parse(nvl(p_parameters, '{}'));
    l_name          varchar2(100) := l_json.get_string('p_name');
    l_department_id number        := l_json.get_number('p_department_id');
    l_job_id        varchar2(20)  := l_json.get_string('p_job_id');
    l_result        clob;
  begin
    select json_arrayagg(
             json_object(
               'employee_id'     value e.employee_id,
               'first_name'      value e.first_name,
               'last_name'       value e.last_name,
               'email'           value e.email,
               'phone_number'    value e.phone_number,
               'hire_date'       value to_char(e.hire_date, 'YYYY-MM-DD'),
               'job_id'          value e.job_id,
               'job_title'       value j.job_title,
               'salary'          value e.salary,
               'department_id'   value e.department_id,
               'department_name' value d.department_name,
               'manager_id'      value e.manager_id
             ) order by e.last_name, e.first_name
             returning clob
           )
      into l_result
      from hr.employees   e
      join hr.jobs        j on j.job_id        = e.job_id
      left join hr.departments d on d.department_id = e.department_id
     where (l_name          is null or upper(e.first_name || ' ' || e.last_name) like '%' || upper(l_name) || '%')
       and (l_department_id is null or e.department_id = l_department_id)
       and (l_job_id        is null or e.job_id        = l_job_id);

    return nvl(l_result, '[]');
  end search_employees;

  -- -------------------------------------------------------------------------
  -- get_employee_details
  -- -------------------------------------------------------------------------
  function get_employee_details (p_parameters in clob) return clob
  as
    l_json        json_object_t := json_object_t.parse(nvl(p_parameters, '{}'));
    l_employee_id number        := l_json.get_number('p_employee_id');
    l_last_name   varchar2(50)  := l_json.get_string('p_last_name');
    l_result      clob;
  begin
    select json_arrayagg(
             json_object(
               'employee_id'     value e.employee_id,
               'first_name'      value e.first_name,
               'last_name'       value e.last_name,
               'email'           value e.email,
               'phone_number'    value e.phone_number,
               'hire_date'       value to_char(e.hire_date, 'YYYY-MM-DD'),
               'job_id'          value e.job_id,
               'job_title'       value j.job_title,
               'salary'          value e.salary,
               'commission_pct'  value e.commission_pct,
               'department_id'   value e.department_id,
               'department_name' value d.department_name,
               'manager_id'      value e.manager_id,
               'manager_name'    value (m.first_name || ' ' || m.last_name),
               'office_city'     value l.city,
               'office_country'  value c.country_name
             )
             returning clob
           )
      into l_result
      from hr.employees   e
      join hr.jobs        j on j.job_id        = e.job_id
      left join hr.departments d on d.department_id = e.department_id
      left join hr.employees   m on m.employee_id   = e.manager_id
      left join hr.locations   l on l.location_id   = d.location_id
      left join hr.countries   c on c.country_id    = l.country_id
     where (l_employee_id is null or e.employee_id = l_employee_id)
       and (l_last_name   is null or upper(e.last_name) like '%' || upper(l_last_name) || '%');

    return nvl(l_result, '[]');
  end get_employee_details;

  -- -------------------------------------------------------------------------
  -- get_departments
  -- -------------------------------------------------------------------------
  function get_departments (p_parameters in clob) return clob
  as
    l_result clob;
  begin
    select json_arrayagg(
             json_object(
               'department_id'   value d.department_id,
               'department_name' value d.department_name,
               'manager_id'      value d.manager_id,
               'manager_name'    value (m.first_name || ' ' || m.last_name),
               'city'            value l.city,
               'state_province'  value l.state_province,
               'country_name'    value c.country_name,
               'headcount'       value (select count(*) from hr.employees e2 where e2.department_id = d.department_id)
             ) order by d.department_name
             returning clob
           )
      into l_result
      from hr.departments d
      left join hr.employees m on m.employee_id = d.manager_id
      left join hr.locations l on l.location_id = d.location_id
      left join hr.countries c on c.country_id  = l.country_id;

    return nvl(l_result, '[]');
  end get_departments;

  -- -------------------------------------------------------------------------
  -- get_jobs
  -- -------------------------------------------------------------------------
  function get_jobs (p_parameters in clob) return clob
  as
    l_result clob;
  begin
    select json_arrayagg(
             json_object(
               'job_id'            value j.job_id,
               'job_title'         value j.job_title,
               'min_salary'        value j.min_salary,
               'max_salary'        value j.max_salary,
               'current_headcount' value (select count(*) from hr.employees e where e.job_id = j.job_id)
             ) order by j.job_title
             returning clob
           )
      into l_result
      from hr.jobs j;

    return nvl(l_result, '[]');
  end get_jobs;

  -- -------------------------------------------------------------------------
  -- get_salary_report
  -- -------------------------------------------------------------------------
  function get_salary_report (p_parameters in clob) return clob
  as
    l_json          json_object_t := json_object_t.parse(nvl(p_parameters, '{}'));
    l_department_id number        := l_json.get_number('p_department_id');
    l_result        clob;
  begin
    select json_arrayagg(
             json_object(
               'department_id'   value d.department_id,
               'department_name' value d.department_name,
               'headcount'       value count(e.employee_id),
               'avg_salary'      value round(avg(e.salary), 2),
               'min_salary'      value min(e.salary),
               'max_salary'      value max(e.salary),
               'total_salary'    value sum(e.salary)
             ) order by sum(e.salary) desc
             returning clob
           )
      into l_result
      from hr.departments d
      join hr.employees   e on e.department_id = d.department_id
     where (l_department_id is null or d.department_id = l_department_id)
     group by d.department_id, d.department_name;

    return nvl(l_result, '[]');
  end get_salary_report;

  -- -------------------------------------------------------------------------
  -- get_employee_hierarchy
  -- -------------------------------------------------------------------------
  function get_employee_hierarchy (p_parameters in clob) return clob
  as
    l_json        json_object_t := json_object_t.parse(nvl(p_parameters, '{}'));
    l_employee_id number        := l_json.get_number('p_employee_id');
    l_result      clob;
  begin
    if l_employee_id is null then
      return '{"error":"p_employee_id is required"}';
    end if;

    select json_arrayagg(
             json_object(
               'hierarchy_level' value lvl,
               'employee_id'     value employee_id,
               'full_name'       value full_name,
               'job_id'          value job_id,
               'manager_id'      value manager_id,
               'salary'          value salary
             ) order by lvl
             returning clob
           )
      into l_result
      from (
        select level                           as lvl,
               employee_id,
               first_name || ' ' || last_name as full_name,
               job_id,
               manager_id,
               salary
          from hr.employees
         start with employee_id = l_employee_id
        connect by prior manager_id = employee_id
      );

    return nvl(l_result, '[]');
  end get_employee_hierarchy;

end uc_ai_data;
/
