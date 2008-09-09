require 'oci8'
require 'test/unit'
require File.dirname(__FILE__) + '/config'
require 'scanf'

class TestDateTime < Test::Unit::TestCase

  def timezone_string(tzh, tzm)
    if tzh >= 0
      format("+%02d:%02d", tzh, tzm)
    else
      format("-%02d:%02d", -tzh, -tzm)
    end
  end

  def setup
    @conn = get_oci8_connection
    @local_timezone = timezone_string(*((::Time.now.utc_offset / 60).divmod 60))
  end

  def teardown
    @conn.logoff
  end

  def test_date_select
    ['2005-12-31 23:59:59',
     '2006-01-01 00:00:00'].each do |date|
      @conn.exec(<<-EOS) do |row|
SELECT TO_DATE('#{date}', 'YYYY-MM-DD HH24:MI:SS') FROM dual
EOS
        assert_equal(Time.local(*date.scanf("%d-%d-%d %d:%d:%d.%06d")), row[0])
      end
    end
  end

  def test_date_out_bind
    cursor = @conn.parse(<<-EOS)
BEGIN
  :out := TO_DATE(:in, 'YYYY-MM-DD HH24:MI:SS');
END;
EOS
    cursor.bind_param(:out, nil, DateTime)
    cursor.bind_param(:in, nil, String, 36)
    ['2005-12-31 23:59:59',
     '2006-01-01 00:00:00'].each do |date|
      cursor[:in] = date
      cursor.exec
      assert_equal(DateTime.parse(date + @local_timezone), cursor[:out])
    end
    cursor.close
  end

  def test_date_in_bind
    cursor = @conn.parse(<<-EOS)
DECLARE
  dt date;
BEGIN
  dt := :in;
  :out := TO_CHAR(dt, 'YYYY-MM-DD HH24:MI:SS');
END;
EOS
    cursor.bind_param(:out, nil, String, 33)
    cursor.bind_param(:in, nil, DateTime)
    ['2005-12-31 23:59:59',
     '2006-01-01 00:00:00'].each do |date|
      cursor[:in] = DateTime.parse(date + @local_timezone)
      cursor.exec
      assert_equal(date, cursor[:out])
    end
    cursor.close
  end

  def test_timestamp_select
    return if $oracle_version < OCI8::ORAVER_9_0

    ['2005-12-31 23:59:59.999999000',
     '2006-01-01 00:00:00.000000000'].each do |date|
      @conn.exec(<<-EOS) do |row|
SELECT TO_TIMESTAMP('#{date}', 'YYYY-MM-DD HH24:MI:SS.FF') FROM dual
EOS
        assert_equal(Time.local(*date.scanf("%d-%d-%d %d:%d:%d.%06d")), row[0])
      end
    end
  end

  def test_timestamp_out_bind
    return if $oracle_version < OCI8::ORAVER_9_0

    cursor = @conn.parse(<<-EOS)
BEGIN
  :out := TO_TIMESTAMP(:in, 'YYYY-MM-DD HH24:MI:SS.FF');
END;
EOS
    cursor.bind_param(:out, nil, DateTime)
    cursor.bind_param(:in, nil, String, 36)
    ['2005-12-31 23:59:59.999999000',
     '2006-01-01 00:00:00.000000000'].each do |date|
      cursor[:in] = date
      cursor.exec
      assert_equal(DateTime.parse(date + @local_timezone), cursor[:out])
    end
    cursor.close
  end

  def test_timestamp_in_bind
    return if $oracle_version < OCI8::ORAVER_9_0

    cursor = @conn.parse(<<-EOS)
BEGIN
  :out := TO_CHAR(:in, 'YYYY-MM-DD HH24:MI:SS.FF');
END;
EOS
    cursor.bind_param(:out, nil, String, 33)
    cursor.bind_param(:in, nil, DateTime)
    ['2005-12-31 23:59:59.999999000',
     '2006-01-01 00:00:00.000000000'].each do |date|
      cursor[:in] = DateTime.parse(date + @local_timezone)
      cursor.exec
      assert_equal(date, cursor[:out])
    end
    cursor.close
  end

  def test_timestamp_tz_select
    return if $oracle_version < OCI8::ORAVER_9_0

    ['2005-12-31 23:59:59.999999000 +08:30',
     '2006-01-01 00:00:00.000000000 -08:30'].each do |date|
      @conn.exec(<<-EOS) do |row|
SELECT TO_TIMESTAMP_TZ('#{date}', 'YYYY-MM-DD HH24:MI:SS.FF TZH:TZM') FROM dual
EOS
        assert_equal(DateTime.parse(date), row[0])
      end
    end
  end

  def test_timestamp_tz_out_bind
    return if $oracle_version < OCI8::ORAVER_9_0

    cursor = @conn.parse(<<-EOS)
BEGIN
  :out := TO_TIMESTAMP_TZ(:in, 'YYYY-MM-DD HH24:MI:SS.FF TZH:TZM');
END;
EOS
    cursor.bind_param(:out, nil, DateTime)
    cursor.bind_param(:in, nil, String, 36)
    ['2005-12-31 23:59:59.999999000 +08:30',
     '2006-01-01 00:00:00.000000000 -08:30'].each do |date|
      cursor[:in] = date
      cursor.exec
      assert_equal(DateTime.parse(date), cursor[:out])
    end
    cursor.close
  end

  def test_timestamp_tz_in_bind
    return if $oracle_version < OCI8::ORAVER_9_0

    cursor = @conn.parse(<<-EOS)
BEGIN
  :out := TO_CHAR(:in, 'YYYY-MM-DD HH24:MI:SS.FF TZH:TZM');
END;
EOS
    cursor.bind_param(:out, nil, String, 36)
    cursor.bind_param(:in, nil, DateTime)
    ['2005-12-31 23:59:59.999999000 +08:30',
     '2006-01-01 00:00:00.000000000 -08:30'].each do |date|
      cursor[:in] = DateTime.parse(date)
      cursor.exec
      assert_equal(date, cursor[:out])
    end
    cursor.close
  end

  def test_datetype_duck_typing
    cursor = @conn.parse("BEGIN :out := :in; END;")
    cursor.bind_param(:in, nil, DateTime)
    cursor.bind_param(:out, nil, DateTime)
    obj = Object.new
    # test year, month, day
    def obj.year; 2006; end
    def obj.month; 12; end
    def obj.day; 31; end
    cursor[:in] = obj
    cursor.exec
    assert_equal(DateTime.parse('2006-12-31'), cursor[:out])
    # test hour
    def obj.hour; 23; end
    cursor[:in] = obj
    cursor.exec
    assert_equal(DateTime.parse('2006-12-31 23:00:00'), cursor[:out])
    # test min
    def obj.min; 59; end
    cursor[:in] = obj
    cursor.exec
    assert_equal(DateTime.parse('2006-12-31 23:59:00'), cursor[:out])
    # test sec
    def obj.sec; 59; end
    cursor[:in] = obj
    cursor.exec
    assert_equal(DateTime.parse('2006-12-31 23:59:59'), cursor[:out])
    # test sec_fraction
    def obj.sec_fraction; DateTime.parse('0001-01-01 00:00:00.000001').sec_fraction * 999999 ; end
    cursor[:in] = obj
    cursor.exec
    assert_equal(DateTime.parse('2006-12-31 23:59:59.999999'), cursor[:out])
    # test utc_offset (Time)
    def obj.utc_offset; @utc_offset; end
    obj.instance_variable_set(:@utc_offset, 9 * 60 * 60)
    cursor[:in] = obj
    cursor.exec
    assert_equal(DateTime.parse('2006-12-31 23:59:59.999999 +09:00'), cursor[:out])
    obj.instance_variable_set(:@utc_offset, -5 * 60 * 60)
    cursor[:in] = obj
    cursor.exec
    assert_equal(DateTime.parse('2006-12-31 23:59:59.999999 -05:00'), cursor[:out])
    # test offset (DateTime)
    def obj.offset; @offset; end
    obj.instance_variable_set(:@offset, 9.to_r / 24)
    cursor[:in] = obj
    cursor.exec
    assert_equal(DateTime.parse('2006-12-31 23:59:59.999999 +09:00'), cursor[:out])
    obj.instance_variable_set(:@offset, -5.to_r / 24)
    cursor[:in] = obj
    cursor.exec
    assert_equal(DateTime.parse('2006-12-31 23:59:59.999999 -05:00'), cursor[:out])
  end

  def test_interval_ym_select
    return if $oracle_version < OCI8::ORAVER_9_0

    [['2006-01-01', '2004-03-01'],
     ['2006-01-01', '2005-03-01'],
     ['2006-01-01', '2006-03-01'],
     ['2006-01-01', '2007-03-01']
    ].each do |date1, date2|
      @conn.exec(<<-EOS) do |row|
SELECT (TO_TIMESTAMP('#{date1}', 'YYYY-MM-DD')
      - TO_TIMESTAMP('#{date2}', 'YYYY-MM-DD')) YEAR TO MONTH
  FROM dual
EOS
        assert_equal(DateTime.parse(date1), DateTime.parse(date2) >> row[0])
      end
    end
  end

  def test_interval_ym_out_bind
    return if $oracle_version < OCI8::ORAVER_9_0

    cursor = @conn.parse(<<-EOS)
DECLARE
  ts1 TIMESTAMP;
  ts2 TIMESTAMP;
BEGIN
  ts1 := TO_TIMESTAMP(:in1, 'YYYY-MM-DD');
  ts2 := TO_TIMESTAMP(:in2, 'YYYY-MM-DD');
  :out := (ts1 - ts2) YEAR TO MONTH;
END;
EOS
    cursor.bind_param(:out, nil, :interval_ym)
    cursor.bind_param(:in1, nil, String, 36)
    cursor.bind_param(:in2, nil, String, 36)
    [['2006-01-01', '2004-03-01'],
     ['2006-01-01', '2005-03-01'],
     ['2006-01-01', '2006-03-01'],
     ['2006-01-01', '2007-03-01']
    ].each do |date1, date2|
      cursor[:in1] = date1
      cursor[:in2] = date2
      cursor.exec
      assert_equal(DateTime.parse(date1), DateTime.parse(date2) >> cursor[:out])
    end
    cursor.close
  end

  def test_interval_ym_in_bind
    return if $oracle_version < OCI8::ORAVER_9_0

    cursor = @conn.parse(<<-EOS)
DECLARE
  ts1 TIMESTAMP;
BEGIN
  ts1 := TO_TIMESTAMP(:in1, 'YYYY-MM-DD');
  :out := TO_CHAR(ts1 + :in2, 'YYYY-MM-DD');
END;
EOS
    cursor.bind_param(:out, nil, String, 36)
    cursor.bind_param(:in1, nil, String, 36)
    cursor.bind_param(:in2, nil, :interval_ym)
    [['2006-01-01', -22],
     ['2006-01-01', -10],
     ['2006-01-01',  +2],
     ['2006-01-01', +12]
    ].each do |date, interval|
      cursor[:in1] = date
      cursor[:in2] = interval
      cursor.exec
      assert_equal(DateTime.parse(date) >> interval, DateTime.parse(cursor[:out]))
    end
    cursor.close
  end

  def test_interval_ds_select
    return if $oracle_version < OCI8::ORAVER_9_0

    [['2006-01-01', '2004-03-01'],
     ['2006-01-01', '2005-03-01'],
     ['2006-01-01', '2006-03-01'],
     ['2006-01-01', '2007-03-01'],
     ['2006-01-01', '2006-01-01 23:00:00'],
     ['2006-01-01', '2006-01-01 00:59:00'],
     ['2006-01-01', '2006-01-01 00:00:59'],
     ['2006-01-01', '2006-01-01 00:00:00.999999'],
     ['2006-01-01', '2006-01-01 23:59:59.999999'],
     ['2006-01-01', '2005-12-31 23:00:00'],
     ['2006-01-01', '2005-12-31 00:59:00'],
     ['2006-01-01', '2005-12-31 00:00:59'],
     ['2006-01-01', '2005-12-31 00:00:00.999999'],
     ['2006-01-01', '2005-12-31 23:59:59.999999']
    ].each do |date1, date2|
      @conn.exec(<<-EOS) do |row|
SELECT (TO_TIMESTAMP('#{date1}', 'YYYY-MM-DD HH24:MI:SS.FF')
      - TO_TIMESTAMP('#{date2}', 'YYYY-MM-DD HH24:MI:SS.FF')) DAY(3) TO SECOND
  FROM dual
EOS
        assert_equal(DateTime.parse(date1) - DateTime.parse(date2), row[0])
      end
    end
  end

  def test_interval_ds_out_bind
    return if $oracle_version < OCI8::ORAVER_9_0

    cursor = @conn.parse(<<-EOS)
DECLARE
  ts1 TIMESTAMP;
  ts2 TIMESTAMP;
BEGIN
  ts1 := TO_TIMESTAMP(:in1, 'YYYY-MM-DD HH24:MI:SS.FF');
  ts2 := TO_TIMESTAMP(:in2, 'YYYY-MM-DD HH24:MI:SS.FF');
  :out := (ts1 - ts2) DAY TO SECOND(9);
END;
EOS
    cursor.bind_param(:out, nil, :interval_ds)
    cursor.bind_param(:in1, nil, String, 36)
    cursor.bind_param(:in2, nil, String, 36)
    [['2006-01-01', '2004-03-01'],
     ['2006-01-01', '2005-03-01'],
     ['2006-01-01', '2006-03-01'],
     ['2006-01-01', '2007-03-01'],
     ['2006-01-01', '2006-01-01 23:00:00'],
     ['2006-01-01', '2006-01-01 00:59:00'],
     ['2006-01-01', '2006-01-01 00:00:59'],
     ['2006-01-01', '2006-01-01 00:00:00.999999'],
     ['2006-01-01', '2006-01-01 23:59:59.999999'],
     ['2006-01-01', '2005-12-31 23:00:00'],
     ['2006-01-01', '2005-12-31 00:59:00'],
     ['2006-01-01', '2005-12-31 00:00:59'],
     ['2006-01-01', '2005-12-31 00:00:00.999999'],
     ['2006-01-01', '2005-12-31 23:59:59.999999']
    ].each do |date1, date2|
      cursor[:in1] = date1
      cursor[:in2] = date2
      cursor.exec
      assert_equal(DateTime.parse(date1) - DateTime.parse(date2), cursor[:out])
    end
    cursor.close
  end

  def test_interval_ds_in_bind
    return if $oracle_version < OCI8::ORAVER_9_0

    cursor = @conn.parse(<<-EOS)
DECLARE
  ts1 TIMESTAMP;
BEGIN
  ts1 := TO_TIMESTAMP(:in1, 'YYYY-MM-DD HH24:MI:SS.FF');
  :out := TO_CHAR(ts1 + :in2, 'YYYY-MM-DD HH24:MI:SS.FF');
END;
EOS
    cursor.bind_param(:out, nil, String, 36)
    cursor.bind_param(:in1, nil, String, 36)
    cursor.bind_param(:in2, nil, :interval_ds)
    [['2006-01-01', -22],
     ['2006-01-01', -10],
     ['2006-01-01',  +2],
     ['2006-01-01', +12],
     ['2006-01-01', -1.to_r / 24], # one hour
     ['2006-01-01', -1.to_r / (24*60)], # one minute
     ['2006-01-01', -1.to_r / (24*60*60)], # one second
     ['2006-01-01', -999999.to_r / (24*60*60*1000000)], # 0.999999 seconds
     ['2006-01-01', +1.to_r / 24], # one hour
     ['2006-01-01', +1.to_r / (24*60)], # one minute
     ['2006-01-01', +1.to_r / (24*60*60)], # one second
     ['2006-01-01', +999999.to_r / (24*60*60*1000000)] # 0.999999 seconds
    ].each do |date, interval|
      cursor[:in1] = date
      cursor[:in2] = interval
      cursor.exec
      assert_equal(DateTime.parse(date) + interval, DateTime.parse(cursor[:out]))
    end
    cursor.close
  end
end # TestOCI8