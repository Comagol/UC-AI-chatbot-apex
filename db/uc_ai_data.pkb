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
    l_min_salary    number        := l_json.get_number('p_min_salary');
    l_max_salary    number        := l_json.get_number('p_max_salary');
    l_order_by      varchar2(30)  := upper(nvl(l_json.get_string('p_order_by'), 'NAME_ASC'));
    l_max_rows      number        := l_json.get_number('p_max_rows');
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
               'commission_pct'  value e.commission_pct,
               'department_id'   value e.department_id,
               'department_name' value d.department_name,
               'manager_id'      value e.manager_id
             ) order by e.sort_key
             returning clob
           )
      into l_result
      from (
        select e.*,
               case l_order_by
                 when 'SALARY_DESC'    then lpad(to_char(99999999 - nvl(e.salary, 0)), 10, '0')
                 when 'SALARY_ASC'     then lpad(to_char(nvl(e.salary, 0)), 10, '0')
                 when 'HIRE_DATE_DESC' then to_char(date '9999-12-31' - nvl(e.hire_date, sysdate), '0000000')
                 when 'HIRE_DATE_ASC'  then to_char(nvl(e.hire_date, sysdate) - date '1900-01-01', '0000000')
                 when 'NAME_DESC'      then upper(e.last_name || e.first_name)
                 else                       lower(e.last_name || e.first_name)
               end as sort_key
          from hr.employees e
         where (l_name          is null or upper(e.first_name || ' ' || e.last_name) like '%' || upper(l_name) || '%')
           and (l_department_id is null or e.department_id = l_department_id)
           and (l_job_id        is null or e.job_id        = l_job_id)
           and (l_min_salary    is null or e.salary       >= l_min_salary)
           and (l_max_salary    is null or e.salary       <= l_max_salary)
         order by sort_key
         fetch first case when l_max_rows is not null then l_max_rows else 9999 end rows only
      ) e
      join hr.jobs        j on j.job_id        = e.job_id
      left join hr.departments d on d.department_id = e.department_id;

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
               'office_country'  value c.country_name,
               'office_region'   value r.region_name
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
      left join hr.regions     r on r.region_id     = c.region_id
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
               'region_name'     value r.region_name,
               'headcount'       value (select count(*) from hr.employees e2 where e2.department_id = d.department_id)
             ) order by d.department_name
             returning clob
           )
      into l_result
      from hr.departments d
      left join hr.employees m on m.employee_id = d.manager_id
      left join hr.locations l on l.location_id = d.location_id
      left join hr.countries c on c.country_id  = l.country_id
      left join hr.regions   r on r.region_id   = c.region_id;

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
    l_direction   varchar2(4)   := upper(nvl(l_json.get_string('p_direction'), 'UP'));
    l_result      clob;
  begin
    if l_employee_id is null then
      return '{"error":"p_employee_id is required"}';
    end if;

    if l_direction = 'DOWN' then
      -- Traverse downward: find all subordinates of the given manager
      -- Note: JOIN inside CONNECT BY is not supported; join to jobs after the hierarchy
      select json_arrayagg(
               json_object(
                 'hierarchy_level' value h.lvl,
                 'employee_id'     value h.employee_id,
                 'full_name'       value h.full_name,
                 'job_id'          value h.job_id,
                 'job_title'       value j.job_title,
                 'manager_id'      value h.manager_id,
                 'salary'          value h.salary
               ) order by h.lvl, h.full_name
               returning clob
             )
        into l_result
        from (
          select level                                as lvl,
                 e.employee_id,
                 e.first_name || ' ' || e.last_name  as full_name,
                 e.job_id,
                 e.manager_id,
                 e.salary
            from hr.employees e
           start with e.manager_id = l_employee_id
          connect by prior e.employee_id = e.manager_id
        ) h
        join hr.jobs j on j.job_id = h.job_id;
    else
      -- Default UP: traverse upward from employee to the top
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
    end if;

    return nvl(l_result, '[]');
  end get_employee_hierarchy;

  -- -------------------------------------------------------------------------
  -- get_job_history
  -- -------------------------------------------------------------------------
  function get_job_history (p_parameters in clob) return clob
  as
    l_json        json_object_t := json_object_t.parse(nvl(p_parameters, '{}'));
    l_employee_id number        := l_json.get_number('p_employee_id');
    l_result      clob;
  begin
    select json_arrayagg(
             json_object(
               'employee_id'     value h.employee_id,
               'full_name'       value (e.first_name || ' ' || e.last_name),
               'start_date'      value to_char(h.start_date, 'YYYY-MM-DD'),
               'end_date'        value to_char(h.end_date, 'YYYY-MM-DD'),
               'duration_years'  value round(months_between(h.end_date, h.start_date) / 12, 1),
               'job_id'          value h.job_id,
               'job_title'       value j.job_title,
               'department_id'   value h.department_id,
               'department_name' value d.department_name
             ) order by h.employee_id, h.start_date
             returning clob
           )
      into l_result
      from hr.job_history  h
      join hr.employees    e on e.employee_id   = h.employee_id
      join hr.jobs         j on j.job_id        = h.job_id
      left join hr.departments d on d.department_id = h.department_id
     where (l_employee_id is null or h.employee_id = l_employee_id);

    return nvl(l_result, '[]');
  end get_job_history;

  -- -------------------------------------------------------------------------
  -- get_locations
  -- -------------------------------------------------------------------------
  function get_locations (p_parameters in clob) return clob
  as
    l_json      json_object_t := json_object_t.parse(nvl(p_parameters, '{}'));
    l_country   varchar2(2)   := upper(l_json.get_string('p_country_id'));
    l_region_id number        := l_json.get_number('p_region_id');
    l_result    clob;
  begin
    select json_arrayagg(
             json_object(
               'location_id'       value l.location_id,
               'street_address'    value l.street_address,
               'city'              value l.city,
               'state_province'    value l.state_province,
               'postal_code'       value l.postal_code,
               'country_id'        value l.country_id,
               'country_name'      value c.country_name,
               'region_id'         value r.region_id,
               'region_name'       value r.region_name,
               'department_count'  value (
                                     select count(*)
                                       from hr.departments d2
                                      where d2.location_id = l.location_id
                                   )
             ) order by c.country_name, l.city
             returning clob
           )
      into l_result
      from hr.locations l
      join hr.countries c on c.country_id = l.country_id
      join hr.regions   r on r.region_id  = c.region_id
     where (l_country   is null or l.country_id = l_country)
       and (l_region_id is null or r.region_id  = l_region_id);

    return nvl(l_result, '[]');
  end get_locations;

  -- -------------------------------------------------------------------------
  -- render_conversation
  -- -------------------------------------------------------------------------
  procedure render_conversation (p_messages_json in clob)
  as
    l_messages json_array_t;
    l_session  json_object_t;
    l_msg      json_object_t;
    l_role     varchar2(20);
    l_content  clob;
  begin
    if p_messages_json is not null and p_messages_json != '[]' then
      -- Support both new session format {"display":[...],"api":[...]} and legacy flat array
      if substr(ltrim(p_messages_json), 1, 1) = '{' then
        l_session  := json_object_t.parse(p_messages_json);
        l_messages := treat(l_session.get('display') as json_array_t);
      else
        l_messages := json_array_t.parse(p_messages_json);
      end if;
      htp.p('<div class="uc-ai-conversation">');
      for i in 0 .. l_messages.get_size - 1 loop
        l_msg     := treat(l_messages.get(i) as json_object_t);
        l_role    := l_msg.get_string('role');
        l_content := l_msg.get_clob('content');
        if l_role = 'user' then
          htp.p('<div class="uc-ai-bubble uc-ai-user">');
          htp.p('<span class="uc-ai-label">You</span>');
          htp.p(apex_escape.html(l_content));
          htp.p('</div>');
        elsif l_role = 'assistant' then
          htp.p('<div class="uc-ai-bubble uc-ai-bot">');
          htp.p('<span class="uc-ai-label">AI Assistant</span>');
          htp.p(apex_escape.html(l_content));
          htp.p('</div>');
        end if;
      end loop;
      htp.p('</div>');
    else
      htp.p('<div class="uc-ai-empty">Ask me anything about the HR data — employees, departments, salaries, job history, locations, or org structure.</div>');
    end if;
  end render_conversation;

  -- -------------------------------------------------------------------------
  -- c_make_msg: internal helper to build a UC AI message object.
  -- UC_AI_GOOGLE requires content to be an array: [{type:"text", text:"..."}]
  -- -------------------------------------------------------------------------
  function c_make_msg (p_role in varchar2, p_text in clob)
    return json_object_t
  as
    l_part    json_object_t := json_object_t();
    l_content json_array_t  := json_array_t();
    l_msg     json_object_t := json_object_t();
  begin
    l_part.put('type', 'text');
    l_part.put('text', p_text);
    l_content.append(l_part);
    l_msg.put('role',    p_role);
    l_msg.put('content', l_content);
    return l_msg;
  end c_make_msg;

  -- -------------------------------------------------------------------------
  -- c_system_prompt: returns the HR assistant system instruction
  -- -------------------------------------------------------------------------
  function c_system_prompt return clob
  as
  begin
    return
      'You are an expert HR data assistant for this company. You have access to the complete HR database ' ||
      'with employees, departments, jobs, job history, locations, countries, and regions.' || chr(10) ||
      chr(10) ||
      'Available tools and when to use them:' || chr(10) ||
      '- HR_SEARCH_EMPLOYEES: Search employees by name, department, job, or salary range. ' ||
      'Use p_order_by=SALARY_DESC + p_max_rows=1 for "highest salary". ' ||
      'Use p_order_by=SALARY_ASC + p_max_rows=1 for "lowest salary". Use p_max_rows=N to limit results. ' ||
      'Use p_department_id to filter by department (get department IDs from HR_GET_DEPARTMENTS first).' || chr(10) ||
      '- HR_GET_EMPLOYEE_DETAILS: Full profile for one employee (manager, city, country, region).' || chr(10) ||
      '- HR_GET_DEPARTMENTS: All departments with manager, city, country_name, region, and headcount. ' ||
      'Use this to find department IDs for a specific country or region before filtering employees.' || chr(10) ||
      '- HR_GET_JOBS: All job titles with salary bands and current headcount.' || chr(10) ||
      '- HR_GET_SALARY_REPORT: Salary stats (avg/min/max/total/headcount) grouped by department. ' ||
      'Call with p_department_id to get stats for one department. ' ||
      'To get salary totals for a country: first call HR_GET_DEPARTMENTS to find the department IDs in that country, then call this tool for each department ID and sum the total_salary values.' || chr(10) ||
      '- HR_GET_EMPLOYEE_HIERARCHY: Use p_direction=UP to find managers up to CEO; p_direction=DOWN to find all subordinates recursively. Returns salary for each person in the hierarchy.' || chr(10) ||
      '- HR_GET_JOB_HISTORY: Past positions an employee held (start date, end date, previous jobs/departments).' || chr(10) ||
      '- HR_GET_LOCATIONS: All office locations with city, country, region.' || chr(10) ||
      chr(10) ||
      'Multi-step reasoning — you MUST do this:' || chr(10) ||
      '- When no single tool directly answers the question, ALWAYS break it into steps. NEVER refuse.' || chr(10) ||
      '- Step pattern for country/region questions: (1) call HR_GET_DEPARTMENTS to get department IDs for that country, (2) call the relevant tool for each department ID, (3) aggregate the results yourself.' || chr(10) ||
      '- Example — "Total salary for US employees": call HR_GET_DEPARTMENTS → filter rows where country_name=''United States'' → for each dept_id call HR_GET_SALARY_REPORT(p_department_id) → sum all total_salary values.' || chr(10) ||
      '- Example — "Employees in same region as X": call HR_GET_EMPLOYEE_DETAILS(X) → read region_name → call HR_GET_DEPARTMENTS → filter by region → call HR_SEARCH_EMPLOYEES for each dept_id.' || chr(10) ||
      '- Example — "Avg salary of subordinates of manager X": call HR_GET_EMPLOYEE_HIERARCHY(X, DOWN) → compute average of salary values in the returned array.' || chr(10) ||
      '- You CAN and MUST perform arithmetic (sum, average, count, percentage) on the JSON data returned by tools.' || chr(10) ||
      chr(10) ||
      'Rules:' || chr(10) ||
      '- Always call the appropriate tool(s) to answer questions. Never guess or fabricate data.' || chr(10) ||
      '- You may call up to 10 tools per response to answer complex questions.' || chr(10) ||
      '- Present results in a clear, human-readable format. For lists, use bullet points or tables.' || chr(10) ||
      '- If a question spans multiple tables (e.g., employee + location + region), use multiple tool calls.';
  end c_system_prompt;

  -- -------------------------------------------------------------------------
  -- c_sys_msg: builds a proper system message object per UC AI docs.
  -- For the messages-array overload, the system message uses plain string content.
  -- -------------------------------------------------------------------------
  function c_sys_msg (p_text in clob) return json_object_t
  as
    l_msg json_object_t := json_object_t();
  begin
    l_msg.put('role',    'system');
    l_msg.put('content', p_text);
    return l_msg;
  end c_sys_msg;

  -- -------------------------------------------------------------------------
  -- run_chatbot
  -- -------------------------------------------------------------------------
  procedure run_chatbot (
    p_user_message  in out nocopy varchar2,
    p_messages_json in out nocopy clob
  )
  as
    -- Display history: simple {role, content:STRING} shown to the user.
    l_display   json_array_t;
    l_disp_msg  json_object_t;
    -- API history: full messages array passed to UC AI (includes tool call history).
    -- Stored as a JSON sub-key inside p_messages_json so it is preserved across turns.
    l_session   json_object_t;
    l_api       json_array_t  := json_array_t();
    l_result    json_object_t;
    l_response  clob;
  begin
    if p_user_message is null then
      return;
    end if;

    -- Parse session state, which holds both display history and full API history.
    -- Format: {"display": [...], "api": [...]}
    -- On the very first call, p_messages_json may be '[]' (legacy) or null.
    if p_messages_json is not null
       and p_messages_json != '[]'
       and substr(ltrim(p_messages_json), 1, 1) = '{'
    then
      l_session := json_object_t.parse(p_messages_json);
      l_display := treat(l_session.get('display') as json_array_t);
      l_api     := treat(l_session.get('api')     as json_array_t);
    else
      l_display := json_array_t();
      l_api     := json_array_t();
      -- First turn: add the system instruction at the top of the API messages.
      -- Per UC AI docs, system message uses plain string content in the messages array.
      l_api.append(c_sys_msg(c_system_prompt));
    end if;

    -- Append the new user message to both display and API history
    l_disp_msg := json_object_t();
    l_disp_msg.put('role',    'user');
    l_disp_msg.put('content', p_user_message);
    l_display.append(l_disp_msg);

    l_api.append(c_make_msg('user', p_user_message));

    -- Call UC AI with HR tools — allow up to 10 sequential tool calls for complex queries
    uc_ai.g_enable_tools := true;
    uc_ai.g_tool_tags    := apex_t_varchar2('hr');

    l_result := uc_ai.generate_text(
      p_messages       => l_api,
      p_provider       => uc_ai.c_provider_google,
      p_model          => uc_ai_google.c_model_gemini_2_5_flash,
      p_max_tool_calls => 10
    );

    l_response := l_result.get_clob('final_message');

    -- Persist the FULL API messages array returned by UC AI.
    -- This preserves tool call/result history between turns, as recommended by docs.
    l_api := treat(l_result.get('messages') as json_array_t);

    -- Append AI response to display history (user-visible only)
    l_disp_msg := json_object_t();
    l_disp_msg.put('role',    'assistant');
    l_disp_msg.put('content', l_response);
    l_display.append(l_disp_msg);

    -- Save both display and full API history in session state
    l_session := json_object_t();
    l_session.put('display', l_display);
    l_session.put('api',     l_api);
    p_messages_json := l_session.to_clob;
    p_user_message  := null;
  exception
    when others then
      raise_application_error(-20100, 'UC AI error: ' || sqlerrm);
  end run_chatbot;

end uc_ai_data;
/
