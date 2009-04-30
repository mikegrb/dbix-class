package DBIx::Class::Storage::DBI::Sybase;

use strict;
use warnings;

use base qw/DBIx::Class::Storage::DBI::NoBindVars/;

sub _rebless {
    my $self = shift;

    my $dbh = $self->schema->storage->dbh;
    my $DBMS_VERSION = @{$dbh->selectrow_arrayref(qq{sp_server_info \@attribute_id=1})}[2];
    if ($DBMS_VERSION =~ /^Microsoft /i) {
        my $subclass = 'DBIx::Class::Storage::DBI::Sybase::MSSQL'; 
        if ($self->load_optional_class($subclass) && !$self->isa($subclass)) {
            bless $self, $subclass;
            $self->_rebless;
        }
    }
}

1;

=head1 NAME

DBIx::Class::Storage::DBI::Sybase - Storage::DBI subclass for Sybase

=head1 SYNOPSIS

This subclass supports L<DBD::Sybase> for real Sybase databases.  If
you are using an MSSQL database via L<DBD::Sybase>, see
L<DBIx::Class::Storage::DBI::Sybase::MSSQL>.

=head1 AUTHORS

Brandon L Black <blblack@gmail.com>

Justin Hunter <justin.d.hunter@gmail.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
