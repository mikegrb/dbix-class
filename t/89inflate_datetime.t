use strict;
use warnings;

use Test::More;
use lib qw(t/lib);
use DBICTest;

{
  local $SIG{__WARN__} = sub { warn @_ if $_[0] !~ /extra \=\> .+? has been deprecated/ };
  DBICTest::Schema->load_classes('EventTZDeprecated');
  DBICTest::Schema->load_classes('EventTZPg');
}

my $schema = DBICTest->init_schema();

plan tests => 57;

SKIP: {
  eval { require DateTime::Format::MySQL };
  skip "Need DateTime::Format::MySQL for inflation tests", 50  if $@;


# inflation test
my $event = $schema->resultset("Event")->find(1);

isa_ok($event->starts_at, 'DateTime', 'DateTime returned');

# klunky, but makes older Test::More installs happy
my $starts = $event->starts_at;
is("$starts", '2006-04-25T22:24:33', 'Correct date/time');

ok(my $row =
  $schema->resultset('Event')->search({ starts_at => $starts })->single);
is(eval { $row->id }, 1, 'DT in search');

ok($row =
  $schema->resultset('Event')->search({ starts_at => { '>=' => $starts } })->single);
is(eval { $row->id }, 1, 'DT in search with condition');

# create using DateTime
my $created = $schema->resultset('Event')->create({
    starts_at => DateTime->new(year=>2006, month=>6, day=>18),
    created_on => DateTime->new(year=>2006, month=>6, day=>23)
});
my $created_start = $created->starts_at;

isa_ok($created->starts_at, 'DateTime', 'DateTime returned');
is("$created_start", '2006-06-18T00:00:00', 'Correct date/time');

## timestamp field
isa_ok($event->created_on, 'DateTime', 'DateTime returned');

## varchar fields
isa_ok($event->varchar_date, 'DateTime', 'DateTime returned');
isa_ok($event->varchar_datetime, 'DateTime', 'DateTime returned');

## skip inflation field
isnt(ref($event->skip_inflation), 'DateTime', 'No DateTime returned for skip inflation column');

# klunky, but makes older Test::More installs happy
my $createo = $event->created_on;
is("$createo", '2006-06-22T21:00:05', 'Correct date/time');

my $created_cron = $created->created_on;

isa_ok($created->created_on, 'DateTime', 'DateTime returned');
is("$created_cron", '2006-06-23T00:00:00', 'Correct date/time');


# Test "timezone" parameter

foreach my $tbl (qw/EventTZ EventTZDeprecated/) {
  my $event_tz = $schema->resultset($tbl)->create({
      starts_at => DateTime->new(year=>2007, month=>12, day=>31, time_zone => "America/Chicago" ),
      created_on => DateTime->new(year=>2006, month=>1, day=>31,
          hour => 13, minute => 34, second => 56, time_zone => "America/New_York" ),
  });

  is ($event_tz->starts_at->day_name, "Montag", 'Locale de_DE loaded: day_name');
  is ($event_tz->starts_at->month_name, "Dezember", 'Locale de_DE loaded: month_name');
  is ($event_tz->created_on->day_name, "Tuesday", 'Default locale loaded: day_name');
  is ($event_tz->created_on->month_name, "January", 'Default locale loaded: month_name');

  my $starts_at = $event_tz->starts_at;
  is("$starts_at", '2007-12-31T00:00:00', 'Correct date/time using timezone');

  my $created_on = $event_tz->created_on;
  is("$created_on", '2006-01-31T12:34:56', 'Correct timestamp using timezone');
  is($event_tz->created_on->time_zone->name, "America/Chicago", "Correct timezone");

  my $loaded_event = $schema->resultset($tbl)->find( $event_tz->id );

  isa_ok($loaded_event->starts_at, 'DateTime', 'DateTime returned');
  $starts_at = $loaded_event->starts_at;
  is("$starts_at", '2007-12-31T00:00:00', 'Loaded correct date/time using timezone');
  is($starts_at->time_zone->name, 'America/Chicago', 'Correct timezone');

  isa_ok($loaded_event->created_on, 'DateTime', 'DateTime returned');
  $created_on = $loaded_event->created_on;
  is("$created_on", '2006-01-31T12:34:56', 'Loaded correct timestamp using timezone');
  is($created_on->time_zone->name, 'America/Chicago', 'Correct timezone');

  # Test floating timezone warning
  # We expect one warning
  SKIP: {
      skip "ENV{DBIC_FLOATING_TZ_OK} was set, skipping", 1 if $ENV{DBIC_FLOATING_TZ_OK};
      local $SIG{__WARN__} = sub {
          like(
              shift,
              qr/You're using a floating timezone, please see the documentation of DBIx::Class::InflateColumn::DateTime for an explanation/,
              'Floating timezone warning'
          );
      };
      my $event_tz_floating = $schema->resultset($tbl)->create({
          starts_at => DateTime->new(year=>2007, month=>12, day=>31, ),
          created_on => DateTime->new(year=>2006, month=>1, day=>31,
              hour => 13, minute => 34, second => 56, ),
      });
      delete $SIG{__WARN__};
  };

  # This should fail to set
  my $prev_str = "$created_on";
  $loaded_event->update({ created_on => '0000-00-00' });
  is("$created_on", $prev_str, "Don't update invalid dates");

  my $invalid = $schema->resultset('Event')->create({
      starts_at  => '0000-00-00',
      created_on => $created_on
  });

  is( $invalid->get_column('starts_at'), '0000-00-00', "Invalid date stored" );
  is( $invalid->starts_at, undef, "Inflate to undef" );

  $invalid->created_on('0000-00-00');
  $invalid->update;

  {
      local $@;
      eval { $invalid->created_on };
      like( $@, qr/invalid date format/i, "Invalid date format exception");
  }
}

## varchar field using inflate_date => 1
my $varchar_date = $event->varchar_date;
is("$varchar_date", '2006-07-23T00:00:00', 'Correct date/time');

## varchar field using inflate_datetime => 1
my $varchar_datetime = $event->varchar_datetime;
is("$varchar_datetime", '2006-05-22T19:05:07', 'Correct date/time');

## skip inflation field
my $skip_inflation = $event->skip_inflation;
is ("$skip_inflation", '2006-04-21 18:04:06', 'Correct date/time');

} # Skip if no MySQL DT::Formatter

SKIP: {
  eval { require DateTime::Format::Pg };
  skip ('Need DateTime::Format::Pg for timestamp inflation tests', 3) if $@;

  my $event = $schema->resultset("EventTZPg")->find(1);
  $event->update({created_on => '2009-01-15 17:00:00+00'});
  $event->discard_changes;
  isa_ok($event->created_on, "DateTime") or diag $event->created_on;
  is($event->created_on->time_zone->name, "America/Chicago", "Timezone changed");
  # Time zone difference -> -6hours
  is($event->created_on->iso8601, "2009-01-15T11:00:00", "Time with TZ correct");
}
