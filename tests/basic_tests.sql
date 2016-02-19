set serveroutput on

@src/register.pks

@src/register.pkb

ALTER PACKAGE register COMPILE PLSQL_CCFLAGS='use_apex:1' REUSE SETTINGS;

begin
  register.dbms_output_enable;
  register.set_dbms_output_level(register.c_trace);
end;
/

-- error
call register.set_dbms_output_level(2);

-- trace
call register.set_dbms_output_level(32);

select register.get_dbms_output_level from dual;

select register.compiler_flags_status from dual;


begin
  register.enter('foo');
end;
/

begin
  register.emit_apex_debug('foo via emit_apex_debug', 2);
end;
/

begin
  register.enter('foo');
  register.assert(FALSE, 'grr');
exception
  when others then
    register.unhandled_exception;
end;
/


begin
  register.enter('foo', 
    'p1', 'v1',
    'p2', 'v2',
    p_action=>'blah'
    );
  register.assert(FALSE, 'grr');
exception
  when others then
    register.unhandled_exception;
end;
/


