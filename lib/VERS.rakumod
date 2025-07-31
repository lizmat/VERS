#- helper subroutines ----------------------------------------------------------

# Is a given string a valid identifier
my sub is-identifier($_) {
    .contains: /^ <[a..z A..Z]> <[a..z A..Z 0..9 . _ -]>+ $/
}

# Dummy infix operator that will always match
my sub whatever($, $ --> True) { }

# Quick-and-dirty percent-decode a string
my sub decode(Str() $_) {
  .subst:
    / '%' <[0..9 a..f A..F]> ** 2 /,
    *.substr(1).parse-base(16).chr,
    :global
}

# Quick lookup of comparators to infix ops
my constant %infix = «
  < less  <= less-or-equal  == equal  != not-equal  >= more-or-equal  > more
»;

#- DefaultComparator -----------------------------------------------------------
# Does the mapping of comparison logic to actual Callables
class DefaultComparator {
    method less()           { &[<]  }
    method less-or-equal()  { &[<=] }
    method equal()          { &[==] }
    method not-equal()      { &[!=] }
    method more-or-equal()  { &[>=] }
    method more()           { &[>]  }
}

#- VersionConstraint -----------------------------------------------------------
class VersionConstraint:ver<0.0.1>:auth<zef:lizmat> {
    has Str $.comparator is built(:bind) = '==';
    has     $.version    is built(:bind);
    has     &!op;
    has     &!equal;

    submethod TWEAK(
      :$version is copy,
      :$compare-logic = DefaultComparator
    --> Nil) {

        my $op-name := %infix{$!comparator}
          // die "Unrecognized comparator '$!comparator'";
        &!op    := $compare-logic."$op-name"();
        &!equal := $compare-logic.equal;

        if $version ~~ Version {
            &!op := &whatever if $version.whatever;
            if $version.plus {
                $!comparator := '>=';
                &!op         := $compare-logic.more-or-equal;
                $!version    := $version.Str.chop.Version;
            }
        }
        elsif $version {  # UNCOVERABLE
            $version = decode($version);
            &!op := &whatever if $version eq '*';

            # Convert to Version object to get correct semantics
            $!version := $version.Version;
        }
        else {
            die "Must have at least a version specified";
        }
    }

    multi method new(VersionConstraint: Str() $spec) {
        $spec.starts-with(">=" | "<=" | "!=")
          ?? self.bless(
               :comparator($spec.substr(0,2)), :version($spec.substr(2))
             )
          !! $spec.starts-with(">" | "<")
            ?? self.bless(
                 :comparator($spec.substr(0,1)), :version($spec.substr(1))
               )
            !! self.bless(:version($spec))
    }

    multi method ACCEPTS(VersionConstraint:D: Version(Cool) $topic --> Bool:D) {
        &!op($topic, $!version)
    }

    method equal(VersionConstraint:D: $topic) {
        &!equal($topic, $!version)
    }

    method negator( VersionConstraint:D:) { $!comparator.starts-with("!") }
    method equallor(VersionConstraint:D:) { $!comparator.substr-eq("=",1) }
    method higheror(VersionConstraint:D:) { $!comparator.starts-with(">") }
    method loweror( VersionConstraint:D:) { $!comparator.starts-with("<") }

    method CALL-ME(VersionConstraint:U: $spec) {
        (try self.new($spec)).Bool
    }

    multi method Str(VersionConstraint:D:) {
        &!op =:= &whatever
          ?? "*"
          !! &!op =:= &[==]
            ?? ~$!version
            !! "$!comparator$!version"
    }
    multi method gist(VersionConstraint:D:) { self.Str }
}

#- VERS ------------------------------------------------------------------------
class VERS:ver<0.0.1>:auth<zef:lizmat> {
    has Str $.scheme = 'vers';
    has Str $.type        is required;
    has     @.constraints is required;
    has     $.comparator-logic = DefaultComparator;

    # Create an argument hash for the given Package URL
    sub hashify(Str:D $spec, $version-logic?) {
        my %args;
        my Str $remainder = $spec.subst(/ \s+ /, :g);;

        # scheme
        with $remainder.index(":") -> $index {
            my $scheme := $remainder.substr(0,$index);

            die "Scheme must be 'vers'" unless $scheme eq 'vers';

            %args<scheme> := $scheme;

            $remainder .= substr($index + 1);
        }
        else {
            die "Must have a scheme specified";
        }

        # type
        with $remainder.index("/") -> $index {
            my $type = $remainder.substr(0,$index).lc;
            die "Invalid type: $type" unless is-identifier($type);  # XXX check for known type

             %args<type> = $type;

            $remainder .= substr($index + 1);
        }
        else {
            die "Must have a type specified";
        }

        %args<constraints> :=
          check-constraints $remainder.split("|", :skip-empty), $version-logic;

        %args
    }

    # Check the validity of the constraints
    sub check-constraints(@constraints is copy, $version-logic is copy) {
        $version-logic = VersionConstraint if $version-logic<> =:= Any;

        @constraints = @constraints.map({
            $_ ~~ $version-logic ?? $_ !! $version-logic.new($_)
        }).sort({ .version unless .negator });

        die "Must have at least one version" unless @constraints;

        # If the only constraint is *, remove all constraints
        if @constraints.head.version eq '*' {
            @constraints == 1
              ?? (return ())
              !! die "Can only have '*' as the only version constraint";
        }

        # Check for duplicate version values
        if @constraints>>.version.repeated -> @repeated {
            die "Version '@repeated.join("', '")' occurred more than once";
        }

        # Weed out any sequential > >= < <= as an optimization
        my $this  = @constraints.head.comparator.substr(0,1);
        my int $i = 1;
        while $i < @constraints {  # UNCOVERABLE
            my $next = @constraints[$i].comparator.substr(0,1);
            if $this eq '>' && $next eq '>' {
                @constraints.splice($i,1);
                ++$i;
            }
            elsif $this eq '<' && $next eq '<' {  # UNCOVERABLE
                @constraints.splice($i - 1, 1);
            }
            else {
                ++$i;
            }
            $this = $next;  # UNCOVERABLE
        }

        # Check the order of constraints
        my $comparator = @constraints.head.comparator;
        for 1..^@constraints -> $i {
            my $next := @constraints[$i].comparator;

            sub check-next(@oks) {
                die "comparator '$next' can not follow '$comparator' in @constraints.join(" | ")"
                  unless $next eq any(@oks);
            }

            if $comparator eq '==' {
                check-next « == > >= »;
            }
            elsif $comparator eq "<" | "<=" {  # UNCOVERABLE
                check-next « > >= »;
            }
            elsif $comparator eq ">" | ">=" {  # UNCOVERABLE
                check-next « < <= »;
            }
            $comparator = $next;
        }

        @constraints
    }

    multi method new(VERS:) {
        %_<constraints> := check-constraints($_, %_<version-logic>)
          with %_<constraints>;
        self.bless: |%_
    }
    multi method new(VERS: Str:D $spec) {
        self.bless: |hashify($spec, %_<version-logic>)
    }

    method from-Version(VERS:U: Version() $version) {
        self.bless(
          :type<raku>,
          :constraints(VersionConstraint.new(:$version))
        )
    }

    multi method Str(VERS:D:) {
        "$!scheme:$!type/" ~ (@!constraints.join(" | ") || "*")
    }
    multi method gist(VERS:D:) {
        self.Str
    }

    method CALL-ME(VERS:U: Str:D $spec --> Bool:D) {
        (try hashify($spec)).Bool
    }

    multi method ACCEPTS(VERS:D: Version(Cool) $topic --> Bool:D) {
        if @!constraints {
            my @ranges;

            for @!constraints {
                if .negator {
                    return False if .equal($topic);
                }
                elsif .equallor {  # UNCOVERABLE
                    return True if .equal($topic);
                    @ranges.push: $_;
                }
                else {
                    @ranges.push: $_;
                }
            }

            if @ranges {
                return $topic ~~ @ranges.head if @ranges == 1;

                my $current = @ranges.head;
                return True if $current.loweror && $topic ~~ $current;

                my int $i = 1;
                for 1..^@ranges.end -> $i {
                    my $next = @ranges[$i];
                    if $current.higheror && $next.loweor {
                        return True if $topic ~~ $current && $topic ~~ $next;
                    }
                    $current = $next;
                }

                return True if $current.higheror && $topic ~~ @ranges.tail;
            }

            $topic ~~ @!constraints.tail;
        }

        else {
            True
        }
    }
}

# vim: expandtab shiftwidth=4
