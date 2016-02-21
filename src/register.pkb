create or replace package body register
as
  -- Note: The license is defined in root of the git repository

-- TODO: assert should go to dbms output even when it is disabled.??
-- Logger will automatically add the backtrace.

m_dbms_output_enabled boolean := TRUE;
m_dbms_output_level integer := c_error;

c_emit_type_enter constant integer := 1;

c_line_feed constant varchar2(1) := chr(10);

TYPE varchar2_table IS TABLE OF VARCHAR2(2000) INDEX BY BINARY_INTEGER;

v_module_stack varchar2_table;
-- TODO: should be similar to FORMAT_CALL_STACK

function level_to_string(p_level integer) return varchar2
as
begin
  if p_level <= c_error then
    return 'error';
  elsif p_level <= c_warn then
    return 'warn';
  elsif p_level <= c_info then
    return 'info';
  elsif p_level <= c_debug then
    return 'debug';
  elsif p_level <= c_trace then
    return 'trace';
  else
    return 'unknown';
  end if;
end;

function compiler_flags_status return varchar2
as
  v_status varchar2(100) := '';
begin
  $if $$use_logger = 1 $then
    v_status := 'Logger: enabled';
  $else
    v_status := 'Logger: disabled';
  $end
  v_status := v_status || c_line_feed;
  $if $$use_apex = 1 $then
    v_status := v_status || 'Apex: enabled';
  $else
    v_status := v_status || 'Apex: disabled';
  $end
  v_status := v_status || c_line_feed;
  return v_status;
end;

procedure raw_assert(
  p_condition in boolean,
  p_msg in varchar2)
as
begin
  if not p_condition or p_condition is null then
    raise_application_error(c_assert_error_number, p_msg);
  end if;
end raw_assert;

procedure emit_dbms_output(
  p_text in clob,
  p_level in integer default c_info)
as
  v_msg CLOB := nvl(p_text, '(null)');
begin
  if m_dbms_output_enabled and p_level <= m_dbms_output_level then
    v_msg := level_to_string(p_level) || ' ' || to_char(sysdate, 'dd.mm.yyyy hh24:mi:ss') || ': ' || v_msg || c_line_feed || DBMS_UTILITY.FORMAT_CALL_STACK;
    
    loop
      exit when v_msg = empty_clob();
      dbms_output.put_line(substr(v_msg, 1, 250));
      v_msg := substr(v_msg, 251);
    end loop;
  end if;
end emit_dbms_output;

procedure emit_logger(
  p_text in varchar2,
  p_extra in clob,
  p_level in integer,
  p_module varchar2
  )
as
  v_module varchar2(200) := p_module;
  v_action varchar2(4000);  -- Unused
  v_scope varchar2(4000);
begin
  $if $$use_logger = 1 $then
    if v_module is null then
      DBMS_APPLICATION_INFO.READ_MODULE(v_module, v_action);
    end if;
    v_scope := v_module || '.' || nvl(v_action, '(no action)');
    if p_level >= c_trace then
      -- this could set the level to c_timing?
      logger.log(p_text, v_scope, p_extra => p_extra);
    elsif p_level = c_debug then
      logger.log(p_text, v_scope, p_extra => p_extra);
    elsif p_level = c_info then
      logger.log_info(p_text, v_scope, p_extra => p_extra);
    elsif p_level = c_warn then
      logger.log_warn(p_text, v_scope, p_extra => p_extra);
    elsif p_level = c_error then
      logger.log_error(p_text, v_scope, p_extra => p_extra);
    elsif p_level = logger.g_permanent then
      logger.log_permanent(p_text, v_scope, p_extra => p_extra);
    end if;
  $else
    raw_assert(TRUE, 'Logger not enabled');
  $end
end emit_logger;

procedure emit_apex_debug(
  p_text in varchar2,
  p_level in integer)
as
begin
  $if $$use_apex = 1 $then
    if p_level >= c_trace then
      apex_debug.trace(p_text);
    elsif p_level = c_debug or p_level = c_info then
      apex_debug.info(p_text);
    elsif p_level = c_warn then
      apex_debug.warn(p_text);
    elsif p_level = c_error then
      apex_debug.error(p_text);
    elsif p_level < c_error then
      -- this is a Logger level
      apex_debug.error('PERMANENT!:' || p_text);
    end if;
  $else
    raw_assert(TRUE, 'APEX debug not enabled');
  $end
end emit_apex_debug;

procedure emit_internal(
  p_module varchar default null,
  p_action varchar default null, -- must be filled if p_module is filled
  p_level integer,
  p_backtrace varchar default null,
  p_text varchar2 default null,
  p_extra clob default null,
  p_emit_type integer default null
  )
as
  v_module varchar2(200) := p_module;
  v_action varchar2(4000) := p_action;
  v_text clob := p_text;
begin
  if v_module is null then
    DBMS_APPLICATION_INFO.READ_MODULE(v_module, v_action);
  end if;

  $if $$use_logger = 1 $then
    emit_logger(
      p_module => p_module,
      p_text => v_text,
      p_extra => p_extra,
      p_level => p_level);
  $end

  if v_text is null then
    if v_action is null and p_emit_type = c_emit_type_enter then
      v_text := v_module || '(Enter)';
    else
      v_text := v_module || '.' || nvl(v_action, '(action not available)');
    end if;
  end if;

  $if $$use_apex = 1 $then
    if p_emit_type is null or p_emit_type != c_emit_type_enter then
      emit_apex_debug(
        p_text => v_text || c_line_feed || p_extra,
        p_level => p_level);
    end if;
  $end
  if m_dbms_output_enabled and p_level <= m_dbms_output_level then
    emit_dbms_output(
      p_text => v_text || c_line_feed || p_extra,
      p_level => p_level);
  end if;
end emit_internal;

procedure emit(
  p_text in varchar2 default null,
  p_level in integer default c_info,
  p_extra in clob default null)
as
begin
  emit_internal(
    p_text => p_text,
    p_level => p_level,
    p_extra => p_extra);
end emit;

procedure assert(
  p_condition in boolean,
  p_msg in varchar2)
as
begin
  if not p_condition or p_condition is null then
    emit(p_msg, p_level => c_error);
    raise_application_error(c_assert_error_number, p_msg);
  end if;
end assert;

function params_to_clob(
  p_name01 IN VARCHAR2 DEFAULT NULL, p_value01 IN VARCHAR2 DEFAULT NULL, 
  p_name02 IN VARCHAR2 DEFAULT NULL, p_value02 IN VARCHAR2 DEFAULT NULL, 
  p_name03 IN VARCHAR2 DEFAULT NULL, p_value03 IN VARCHAR2 DEFAULT NULL, 
  p_name04 IN VARCHAR2 DEFAULT NULL, p_value04 IN VARCHAR2 DEFAULT NULL, 
  p_name05 IN VARCHAR2 DEFAULT NULL, p_value05 IN VARCHAR2 DEFAULT NULL, 
  p_name06 IN VARCHAR2 DEFAULT NULL, p_value06 IN VARCHAR2 DEFAULT NULL, 
  p_name07 IN VARCHAR2 DEFAULT NULL, p_value07 IN VARCHAR2 DEFAULT NULL, 
  p_name08 IN VARCHAR2 DEFAULT NULL, p_value08 IN VARCHAR2 DEFAULT NULL, 
  p_name09 IN VARCHAR2 DEFAULT NULL, p_value09 IN VARCHAR2 DEFAULT NULL, 
  p_name10 IN VARCHAR2 DEFAULT NULL, p_value10 IN VARCHAR2 DEFAULT NULL)
return
  clob
as
  v_clob clob;
begin
  if p_name01 is null then
    return '';
  else
    v_clob := p_name01 || '=' || nvl(p_value01, null) || ',';
  end if;

  if p_name02 is not null then
    v_clob := v_clob || p_name02 || '=' || nvl(p_value02, 'null') || ',';
  end if;
  if p_name03 is not null then
    v_clob := v_clob || p_name03 || '=' || nvl(p_value03, 'null') || ',';
  end if;
  if p_name04 is not null then
    v_clob := v_clob || p_name04 || '=' || nvl(p_value04, 'null') || ',';
  end if;
  if p_name05 is not null then
    v_clob := v_clob || p_name05 || '=' || nvl(p_value05, 'null') || ',';
  end if;
  if p_name06 is not null then
    v_clob := v_clob || p_name06 || '=' || nvl(p_value06, 'null') || ',';
  end if;
  if p_name07 is not null then
    v_clob := v_clob || p_name07 || '=' || nvl(p_value07, 'null') || ',';
  end if;
  if p_name08 is not null then
    v_clob := v_clob || p_name08 || '=' || nvl(p_value08, 'null') || ',';
  end if;
  if p_name09 is not null then
    v_clob := v_clob || p_name09 || '=' || nvl(p_value09, 'null') || ',';
  end if;
  if p_name10 is not null then
    v_clob := v_clob || p_name10 || '=' || nvl(p_value10, 'null') || ',';
  end if;
  return substr(v_clob , 1, length(v_clob) - 1);
end;

procedure enter(
  p_module in varchar2,
  p_name01 IN VARCHAR2 DEFAULT NULL, p_value01 IN VARCHAR2 DEFAULT NULL, 
  p_name02 IN VARCHAR2 DEFAULT NULL, p_value02 IN VARCHAR2 DEFAULT NULL, 
  p_name03 IN VARCHAR2 DEFAULT NULL, p_value03 IN VARCHAR2 DEFAULT NULL, 
  p_name04 IN VARCHAR2 DEFAULT NULL, p_value04 IN VARCHAR2 DEFAULT NULL, 
  p_name05 IN VARCHAR2 DEFAULT NULL, p_value05 IN VARCHAR2 DEFAULT NULL, 
  p_name06 IN VARCHAR2 DEFAULT NULL, p_value06 IN VARCHAR2 DEFAULT NULL, 
  p_name07 IN VARCHAR2 DEFAULT NULL, p_value07 IN VARCHAR2 DEFAULT NULL, 
  p_name08 IN VARCHAR2 DEFAULT NULL, p_value08 IN VARCHAR2 DEFAULT NULL, 
  p_name09 IN VARCHAR2 DEFAULT NULL, p_value09 IN VARCHAR2 DEFAULT NULL, 
  p_name10 IN VARCHAR2 DEFAULT NULL, p_value10 IN VARCHAR2 DEFAULT NULL, 
  p_action varchar2 default null,
  p_extra clob default null)
as
  v_previous_module varchar2(200);
  v_previous_action varchar2(4000); -- unused
begin
  DBMS_APPLICATION_INFO.READ_MODULE(v_previous_module, v_previous_action);
  --assert( v_module_stack.LAST = 0 or v_previous_module is null );
  if v_previous_module is null then
    v_previous_module := '(root)';
  end if;

  --v_module_stack(v_module_stack.COUNT) := p_module;
  -- assert v$session is OK
  dbms_application_info.set_module(p_module, p_action);
  $if $$use_apex = 1 $then
    apex_debug.enter(p_module,
                     p_name01, p_value01,
                     p_name02, p_value02,
                     p_name03, p_value03,
                     p_name04, p_value04,
                     p_name05, p_value05,
                     p_name06, p_value06,
                     p_name07, p_value07,
                     p_name08, p_value08,
                     p_name09, p_value09,
                     p_name10, p_value10,
                     p_value_max_length => 4000);
  $end
  emit_internal(
       p_module => p_module,
       p_action => p_action,
       p_level => c_trace,
       p_extra => params_to_clob(
                    p_name01, p_value01,
                    p_name02, p_value02,
                    p_name03, p_value03,
                    p_name04, p_value04,
                    p_name05, p_value05,
                    p_name06, p_value06,
                    p_name07, p_value07,
                    p_name08, p_value08,
                    p_name09, p_value09,
                    p_name10, p_value10
                  ),
       p_emit_type => c_emit_type_enter);
end;

procedure set_action(p_action varchar2)
as
begin
  dbms_application_info.set_action(p_action);
  emit(p_action, p_level => c_trace);
end;

procedure visit(
  p_module in varchar2,
  p_action in varchar2)
as
begin
  null; -- if the current module is not entered yet, then enter
end visit;

-- TODO: verify the stack counting is all working.
procedure exit(
  p_module in varchar2 default null)
as
  v_current_module varchar2(200);
  v_current_action varchar2(4000); -- unused
begin
  if p_module is not null then
    DBMS_APPLICATION_INFO.READ_MODULE(v_current_module, v_current_action);
    --assert(v_current_module = p_module, 'Exiting ' || p_module || ' ; after entering ' || v_current_module);
  end if;
  --v_current_module := v_module_stack(v_module_stack.LAST); --.column_value;
  dbms_application_info.set_module(v_current_module, null);
  --v_module_stack.delete(v_module_stack.LAST);
end;

procedure exception_exit(
  p_text varchar2 default null,
  p_level integer default c_info)
as
  v_stack varchar2(4000);
begin
  v_stack := DBMS_UTILITY.FORMAT_ERROR_STACK || c_line_feed || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
  emit('Correctly handled exception: ' || v_stack, p_level=>c_info);
end;

procedure unhandled_exception(
  p_text varchar2 default null,
  p_level integer default c_error)
as
  v_stack varchar2(4000);
begin
  v_stack := DBMS_UTILITY.FORMAT_ERROR_STACK || c_line_feed || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
  emit('Unexpected exception: ' || v_stack, p_level=>c_error);
end;

procedure emit_helper(
  p_text varchar2 default null,
  p_level integer default c_info,
  p_module varchar2 default 'n/a',
  p_action varchar2 default null,
  p_extra clob default null)
as
begin
  visit(p_module, p_action);
  emit(p_text);
end;

procedure error(p_text varchar2) as begin emit_helper(p_text, c_error); end;
procedure warn(p_text varchar2) as begin emit_helper(p_text, c_warn); end;
procedure info(p_text varchar2) as begin emit_helper(p_text, c_info); end;
procedure debug(p_text varchar2) as begin emit_helper(p_text, c_debug); end;
procedure trace(p_text varchar2) as begin emit_helper(p_text, c_trace); end;

procedure dbms_output_enable as begin m_dbms_output_enabled := TRUE; end;

procedure dbms_output_disable as begin m_dbms_output_enabled := FALSE; end;
  
procedure set_dbms_output_level(p_level integer)
as
begin
  m_dbms_output_level := p_level;
end;

function get_dbms_output_level return integer is
begin
  return m_dbms_output_level;
end;

end register;
/
