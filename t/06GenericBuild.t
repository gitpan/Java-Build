use strict;
use warnings;

use Test::More tests => 9;

BEGIN { use_ok('Java::Build::GenericBuild') }

my $builder = MyBuild->new();
is($builder->{MISSING}, 12, "process one attr");

my $targets = [ qw(init purge checkout compile make_jars) ];
$builder->targets($targets);
is_deeply($targets, $builder->{TARGETS}, "targets set");

eval q{
    $builder->GO();
};
like($@, qr/supply a BUILD_SUCCESS/, 'no success file');

open SUCCESS, '>t/generic.success' or die "couldn't write success file\n";
print SUCCESS "last_successful_target=";
$builder->{BUILD_SUCCESS} = 't/generic.success';

eval q{
    $builder->GO();
};
like($@, qr/Can.t locate.*init/, 'missing sub');

$targets = [ qw(step1 step2 step3 step4 step5) ];
$builder->targets($targets);
$builder->GO();
is($builder->{STEPS}, 'step1step2step3step4step5', 'full build');

$builder->{STEPS} = "";
$builder->GO("step3");
is($builder->{STEPS}, 'step1step3', 'redo step3');

$builder->{STEPS} = "";
$builder->GO("step5");
is($builder->{STEPS}, 'step1step4step5', 'redo from step3 to step5');

unlink 't/generic.success';
open SUCCESS, '>t/generic.success' or die "couldn't write success file\n";
print SUCCESS "last_successful_target=";

$builder->{STEPS} = "";
$builder->GO("step3");
is($builder->{STEPS}, 'step1step2step3', 'scratch to step3');

unlink 't/generic.success';
package MyBuild;
use base 'Java::Build::GenericBuild';

sub new {
    my $class = shift;
    my $self  = {
        ATTRIBUTES => [
            { MISSING => sub { my $s = shift; $s->{MISSING} = 12; } },
        ],
    };
    Java::Build::GenericBuild::process_attrs($self);
    bless $self, $class;
}

sub step1 { $_[0]->{STEPS}  = "step1"; }
sub step2 { $_[0]->{STEPS} .= "step2"; }
sub step3 { $_[0]->{STEPS} .= "step3"; }
sub step4 { $_[0]->{STEPS} .= "step4"; }
sub step5 { $_[0]->{STEPS} .= "step5"; }

__END__

#___________________ Read Props ________________
eval q{
    my $bad_config = read_prop_file('t/missing.config');
};
like ($@, qr/Couldn.t read/, "attempt to read missing prop file");

my $config = read_prop_file('t/sample.config');
is($config->{basedir}, "/some/path", "read a config");

open PROPS, ">t/sample.properties"
    or die "Couldn't write t/sample.properties $!\n";

print PROPS <<EOP;
full.name=Java::Build::Tasks
short.name=Tasks
EOP

close PROPS;

#___________________ Update Props ________________

eval q{update_prop_file();};
like($@, qr/supply.*NAME/, "no args to update_prop_file");

update_prop_file(
    NAME      => "t/sample.properties",
    NEW_PROPS => {
        "short.name" => "MyTasks",
        "new.name"   => "Java::Build::MyTasks",
    },
);

my $new_props = read_prop_file("t/sample.properties");
my $correct_props = {
    "full.name"  => "Java::Build::Tasks",
    "short.name" => "MyTasks",
    "new.name"   => "Java::Build::MyTasks",
};

is_deeply($new_props, $correct_props, "existing props updated");

update_prop_file(
    NAME => "t/not_distributed.props",
    NEW_PROPS => {
        discussion => "This file should be created by this call",
    },
);

unless (open NOT_DIST, "t/not_distributed.props") {
    fail('props file created');
}
else {
    my $prop = join "", <NOT_DIST>;
    is (
        $prop,
        "discussion=This file should be created by this call\n",
        'props file created'
    );
}

unlink 't/not_distributed.props';

#___________________ Copy ________________

copy_file('t/file2copy', 't/copiedfile');
open ORIG, 't/file2copy';
open COPY, 't/copiedfile';
my $orig = join "", <ORIG>;
my $copy = join "", <COPY>;
close COPY;
close ORIG;

is($copy, $orig, "file copy");
unlink 't/copiedfile';

eval q{
    copy_file('t/missingfile', 't/copiedfile');
};
like($@, qr/couldn.t cp/, "bad copy");

#___________________ Jar Class Path ________________

my $jar_path = make_jar_classpath(DIRS => [ 't/jars/lib1', 't/jars/lib2' ]);
my @generated = sort(split(/:/, $jar_path));
my @actual   = sort qw(
    t/jars/lib1/dummy.jar
    t/jars/lib1/dummy2.jar
    t/jars/lib1/dummy3.jar
    t/jars/lib2/smarty.jar
    t/jars/lib2/smarty2.jar
    t/jars/lib2/smarty3.jar
);
is("@generated", "@actual", "make_jar_classpath");

#___________________ Purging ________________

SKIP: {
    my $make_status = mkdir 't/doomed';
    `touch t/doomed/file`;
    skip "couldn't make directory under t", 1, if ($?);

    purge_dirs('t', qw(doomed) );
    if (open DECEASED, 't/doomed/file') {
        fail("purge directory");
        close DECEASED;
    }
    else {
        pass("purge directory");
    }
}

# Insert new tests immediately above this line, mess not with logging.

#___________________ Logging ________________
my $logger = Logger->new();
Java::Build::Tasks::set_logger($logger);
eval q{update_prop_file();};

package Logger;
use Test::More;

sub new { my $class = shift; my $self = {}; bless $self, $class }
sub log {
    my $self     = shift;
    my $message  = shift;
    my $severity = shift;

    like($message, qr/didn.t supply/, "logged message");
    is($severity,  100, "log severity");
}

