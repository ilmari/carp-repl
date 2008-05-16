package Carp::REPL;
use strict;
use warnings;
use 5.6.0;
our $VERSION = '0.12';

use base 'Exporter';
our @EXPORT_OK = 'repl';

our $noprofile = 0;

sub import {
    my $nodie  = grep { $_ eq 'nodie'    } @_;
    my $warn   = grep { $_ eq 'warn'     } @_;
    $noprofile = grep { $_ eq 'noprofile'} @_;

    $SIG{__DIE__}  = \&repl unless $nodie;
    $SIG{__WARN__} = \&repl if $warn;
}

sub repl {
    warn @_, "\n"; # tell the user what blew up

    require PadWalker;
    require Devel::REPL::Script;

    my (@packages, @environments, @argses, $backtrace);

    my $frame = 0;
    while (1) {
        package DB;
        my ($package, $file, $line, $subroutine) = caller($frame)
            or last;
        $package = 'main' if !defined($package);

        eval {
            # PadWalker has 0 mean 'current'
            # caller has 0 mean 'immediate caller'
            push @environments, PadWalker::peek_my($frame+1);
        };

        Carp::carp($@), last if $@;

        push @argses, [@DB::args];
        push @packages, [$package, $file, $line];

        $backtrace .= sprintf "%s%d: %s called at %s:%s.\n",
            $frame == 0 ? '' : '   ',
            $frame,
            $subroutine,
            $file,
            $line;

        ++$frame;
    }

    warn $backtrace;

    my ($runner, $repl);

    if ($noprofile) {
        $repl = $runner = Devel::REPL->new;
    }
    else {
        $runner = Devel::REPL::Script->new;
        $repl = $runner->_repl;
    }

    $repl->load_plugin('Carp::REPL');

    $repl->environments(\@environments);
    $repl->packages(\@packages);
    $repl->argses(\@argses);
    $repl->backtrace($backtrace);
    $repl->frame(0);
    $runner->run;
}

1;

__END__

=head1 NAME

Carp::REPL - read-eval-print-loop on die and/or warn

=head1 VERSION

Version 0.12 released ???

=head1 SYNOPSIS

The intended way to use this module is through the command line.

    perl tps-report.pl
        Can't call method "cover_sheet" without a package or object reference at tps-report.pl line 6019.


    perl -MCarp::REPL tps-report.pl
        Can't call method "cover_sheet" without a package or object reference at tps-report.pl line 6019.

    # instead of exiting, you get a REPL!

    $ $form
    27B/6

    $ $self->get_form
    27B/6

    $ "ah ha! there's my bug"
    ah ha! there's my bug

=head1 USAGE

=head2 C<-MCarp::REPL>
=head2 C<-MCarp::REPL=warn>

Works as command line argument. This automatically installs the die handler for
you, so if you receive a fatal error you get a REPL before the universe
explodes. Specifying C<=warn> also installs a warn handler for finding those
mysterious warnings.

=head2 C<use Carp::REPL;>
=head2 C<use Carp::REPL 'warn';>

Same as above.

=head2 C<use Carp::REPL 'nodie';>

Loads the module without installing the die handler. Use this if you just want
to run C<Carp::REPL::repl> on your own terms.

=head1 FUNCTIONS

=head2 repl

This module's interface consists of exactly one function: repl. This is
provided so you may install your own C<$SIG{__DIE__}> handler if you have no
alternatives.

It takes the same arguments as die, and returns no useful value. In fact, don't
even depend on it returning at all!

One useful place for calling this manually is if you just want to check the
state of things without having to throw a fake error. You can also change any
variables and those changes will be seen by the rest of your program.

    use Carp::REPL 'repl';

    sub involved_calculation {
        # ...
        $d = maybe_zero();
        # ...
        repl(); # $d = 1
        $sum += $n / $d;
        # ...
    }

Unfortunately if you instead go with the usual C<-MCarp::REPL>, then
C<$SIG{__DIE__}> will be invoked and there's no general way to recover. But you
can still change variables to poke at things.

=head1 COMMANDS

Note that this is not supposed to be a full-fledged debugger. A few commands
are provided to aid you in finding out what went awry. See
L<Devel::ebug> if you're looking for a serious debugger.

=over 4

=item * :u

Moves one frame up in the stack.

=item * :d

Moves one frame down in the stack.

=item * :t

Redisplay the stack trace.

=item * :e

Display the current lexical environment.

=item * :l

List eleven lines of source code of the current frame.

=item * :q

Close the REPL. (C<^D> also works)

=back

=head1 VARIABLES

=over 4

=item * $_REPL

This represents the Devel::REPL object (with the LexEnvCarp plugin, among
others, mixed in).

=item * $_a

This represents the arguments passed to the subroutine at the current frame in
the call stack. Modifications are ignored (how would that work anyway?
Re-invoke the sub?)

=back

=head1 CAVEATS

Dynamic scope probably produces unexpected results. I don't see any easy (or
even difficult!) solution to this. Therefore it's a caveat and not a bug. :)

=head1 SEE ALSO

L<Devel::REPL>, L<Devel::ebug>

=head1 AUTHOR

Shawn M Moore, C<< <sartak at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-carp-repl at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Carp-REPL>.

=head1 ACKNOWLEDGEMENTS

Thanks to Nelson Elhage and Jesse Vincent for the idea.

Thanks to Matt Trout and Stevan Little for their advice.

=head1 COPYRIGHT & LICENSE

Copyright 2007-2008 Best Practical Solutions, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

