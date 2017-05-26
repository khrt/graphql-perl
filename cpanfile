# vim: ft=perl
requires 'perl' => '5.010000';

requires 'Data::Dumper' => '2.131';
requires 'JSON' => '2.90';
requires 'List::Util' => '1.26';

on test => sub {
    requires 'Test::Deep' => '1.127';
    requires 'Test::More' => '1.302085';
};

on develop => sub {
    requires 'Data::Printer' => '0.39';
};
