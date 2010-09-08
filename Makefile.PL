use inc::Module::Install;

name 'CraigHome';
all_from 'lib/CraigHome.pm';

requires(
    'CGI'                   => 0,
    'Email::Stuff'          => 0,
    'KiokuDB'               => 0,
    'KiokuDB::Backend::DBI' => 0,
    'Scrappy'               => 0,
    'Time::HiRes'           => 0,
);

auto_install;
WriteAll;
