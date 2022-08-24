create or replace procedure wait(in interval_time interval)
begin
  declare now timestamp default current_timestamp();
  declare finish timestamp default now + interval_time;

  repeat
    set now = current_timestamp();
    until now >= finish;
  end repeat
end
