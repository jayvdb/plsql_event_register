create or replace package register
  authid CURRENT_USER
as
  -- Note: The license is defined in root of the git repository

  -- Assertion number
  c_assert_error_number pls_integer := -20000;

  c_error number := 2;
  c_warn number := 4;
  c_info number := 8;
  c_debug number := 16;
  c_trace number := 32;

  procedure enter(
    p_module varchar2,
    p_name01 IN VARCHAR2 DEFAULT NULL, 
    p_value01 IN VARCHAR2 DEFAULT NULL, 
    p_name02 IN VARCHAR2 DEFAULT NULL, 
    p_value02 IN VARCHAR2 DEFAULT NULL, 
    p_name03 IN VARCHAR2 DEFAULT NULL, 
    p_value03 IN VARCHAR2 DEFAULT NULL, 
    p_name04 IN VARCHAR2 DEFAULT NULL, 
    p_value04 IN VARCHAR2 DEFAULT NULL, 
    p_name05 IN VARCHAR2 DEFAULT NULL, 
    p_value05 IN VARCHAR2 DEFAULT NULL, 
    p_name06 IN VARCHAR2 DEFAULT NULL, 
    p_value06 IN VARCHAR2 DEFAULT NULL, 
    p_name07 IN VARCHAR2 DEFAULT NULL, 
    p_value07 IN VARCHAR2 DEFAULT NULL, 
    p_name08 IN VARCHAR2 DEFAULT NULL, 
    p_value08 IN VARCHAR2 DEFAULT NULL, 
    p_name09 IN VARCHAR2 DEFAULT NULL, 
    p_value09 IN VARCHAR2 DEFAULT NULL, 
    p_name10 IN VARCHAR2 DEFAULT NULL, 
    p_value10 IN VARCHAR2 DEFAULT NULL, 
    p_action varchar2 default null,
    p_extra clob default null
  );

  procedure set_action(p_action varchar2);

  procedure assert(
    p_condition in boolean,
    p_msg in varchar2);

  procedure exit(p_module varchar2 default null);

  procedure error(p_text varchar2);
  procedure warn(p_text varchar2);
  procedure info(p_text varchar2);
  procedure debug(p_text varchar2);
  procedure trace(p_text varchar2);

  -- to be used in 'when others then'
  procedure unhandled_exception(
    p_text varchar2 default null,
    p_level integer default c_error);

  -- to be used in specific exception handling
  procedure exception_exit(
    p_text varchar2 default null,
    p_level integer default c_info);

  procedure emit_dbms_output(
    p_text in clob,
    p_level in integer default c_info);
  procedure emit_apex_debug(
    p_text in varchar2,
    p_level in integer);

  procedure emit(
    p_text in varchar2 default null,
    p_level in integer default c_info,
    p_extra in clob default null);

  procedure emit_helper(
    p_text varchar2 default null,
    p_level integer default c_info,
    p_module varchar2 default 'n/a',
    p_action varchar2 default null,
    p_extra clob default null);

  -- note this affects all users; disable in production
  procedure dbms_output_enable;
  procedure dbms_output_disable;
  
  -- note this affects all users; disable in production
  procedure set_dbms_output_level(p_level integer);
  function get_dbms_output_level return integer;

  function compiler_flags_status return varchar2;

end register;
/
