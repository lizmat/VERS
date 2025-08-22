use VERS::Type:ver<0.0.3>:auth<zef:lizmat>;

#- helpers ---------------------------------------------------------------------
# Quick-and-dirty percent-decode a string
my sub decode(Str() $_) {
  .subst:
    / '%' <[0..9 a..f A..F]> ** 2 /,
    *.substr(1).parse-base(16).chr,
    :global
}

#- VersionConstraint -----------------------------------------------------------
class VersionConstraint {
    has Str $.comparator is built(:bind) is required;
    has     $.version    is built(:bind) is required;

    multi method ACCEPTS(VersionConstraint:D: Any:D $topic --> Bool:D) {
        $topic."$!comparator"($!version)
    }

    method equal(VersionConstraint:D: $topic) {
        $topic."=="($!version)
    }

    method negator( VersionConstraint:D:) { $!comparator.starts-with("!") }
    method equallor(VersionConstraint:D:) { $!comparator.substr-eq("=",1) }
    method higheror(VersionConstraint:D:) { $!comparator.starts-with(">") }
    method loweror( VersionConstraint:D:) { $!comparator.starts-with("<") }

    multi method Str(VersionConstraint:D:) {
        $!comparator eq '=='
          ?? ~$!version
          !! "$!comparator$!version"
    }
}

#- VERS ------------------------------------------------------------------------
class VERS:ver<0.0.3>:auth<zef:lizmat> {
    has Str $.scheme = 'vers';
    has     $.type        is required;
    has     @.constraints is required;

    # Create an argument hash for the given Package URL
    sub hashify(Str:D $spec) {
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
            my $part := $remainder.substr(0,$index).lc;
            my $type := VERS::Type($part);
            die "Invalid type: $part" if $type ~~ Failure;

            %args<type> = $type;

            $remainder .= substr($index + 1);
        }
        else {
            die "Must have a type specified";
        }

        if $remainder.split("|", :skip-empty) -> @constraints {
            %args<constraints> := @constraints.List;
        }
        else {
            die "Must have at least one constraint specified";
        }

        %args
    }

    multi method new(VERS: Str:D $spec) {
        self.bless: |hashify(decode($spec))
    }

    # Check the validity of the constraints
    submethod TWEAK(--> Nil) {
        # Nothing to check: no constraints means anything goes
        return unless @!constraints;

        my $Version := VERS::Type($!type).Version;
        my @constraints = @!constraints.map({
            if $_ ~~ VersionConstraint {
                $_
            }
            else {
                my $comparator;
                my $version;
                if .starts-with(">=" | "<=" | "!=") {
                    $comparator := .substr(0,2);
                    $version    := .substr(2);
                }
                elsif .starts-with(">" | "<") {  # UNCOVERABLE
                    $comparator := .substr(0,1);
                    $version    := .substr(1);
                }
                else {
                    $comparator := '==';  # UNCOVERABLE
                    $version    := $_;
                }
                $version := $Version.new($version);

                VersionConstraint.new(:$comparator, :$version)
            }
        }).sort({
            $^a.negator
              ?? Less
              !! $^a.version.cmp($^b.version)
        });

        # If the only constraint is *, remove all constraints
        if @constraints.head.version eq '*' {
            if @constraints == 1  {
                @!constraints := ();
                return;
            }
            die "Can only have '*' as the only version constraint";
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

        @!constraints := @constraints.List;
    }

    method from-Version(VERS:U: Version() $version is copy) {

        # No constraints if a whatever version
        return self.bless(:type<raku>, :constraints(())) if $version.whatever;

        # Set comparator and version string
        my $comparator;
        if $version.plus {
            $comparator := '>=';  # UNCOVERABLE
            $version     = $version.Str.chop;
        }
        else {
            $comparator := '==';  # UNCOVERABLE
            $version    .= Str;
        }
        $version = VERS::Type("raku").Version($version);

        self.bless(
          :type<raku>,
          :constraints(VersionConstraint.new(:$comparator, :$version))
        )
    }

    multi method Str(VERS:D:) {
        "$!scheme:$!type/" ~ (@!constraints.join("|") || "*")
    }
    multi method gist(VERS:D:) {
        self.Str
    }

    method CALL-ME(VERS:U: Str:D $spec --> Bool:D) {
        (try hashify($spec)).Bool
    }

    multi method ACCEPTS(VERS:D: Str:D $topic --> Bool:D) {
        self.ACCEPTS(VERS::Type($!type).Version($topic))
    }
    multi method ACCEPTS(VERS:D: Any:D $topic --> Bool:D) {
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
