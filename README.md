# plsql_event_register

This PL/SQL logging/event package, called `register`, is a simple framework
for instrumentation of PL/SQL code, including tracing, assertions and error
levels, with the ability to send these event messages to both the
developer console (`dbms_output`) and/or to application logging frameworks.

The only mandatory component is the PL/SQL package `register`.  If this is
the only object installed, the log events are only reported to dbms_output,
when the event is above a configurable event/error level, and are not stored
anywhere.

The events may also be routed into many other frameworks, such as `apex_debug`
and PL/SQL Logger, which store the event based on configuration of those
frameworks.

Installation
============

To install only dbms_output logging, simply load `src/register.*` and compile
into them into the target schema.

The `register` package uses PL/SQL compiler flags to include or exclude
functionality, such as Logger and APEX support.

The flags are:

1. `use_logger`: Hooks into the `Logger` package.
2. `use_apex`: Hooks into the `APEX_DEBUG` package.

See http://www.oratechinfo.co.uk/plsql_compiler_flags.html
