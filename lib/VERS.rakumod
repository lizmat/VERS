use Identity::Utils:ver<0.0.25+>:auth<zef:lizmat> <
  version
>;

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
my constant %infix =
  "<"  => &[<],
  "<=" => &[<=],
  "==" => &[==],
  "!=" => &[!=],
  ">=" => &[>=],
  ">"  => &[>],
;

#- VersionConstraint -----------------------------------------------------------
class VersionConstraint:ver<0.0.1>:auth<zef:lizmat> {
    has Str $.comperator = '==';
    has     $.version is built(:bind);
    has     &!op;

    submethod TWEAK(:$version is copy --> Nil) {

        &!op := %infix{$!comperator}
          // die "Unrecognized comperator '$!comperator'";

        if $version ~~ Version {
            &!op := &whatever if $version.whatever;
            &!op := &[>=]     if $version.plus;
        }
        elsif $version {
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
               :comperator($spec.substr(0,2)), :version($spec.substr(2))
             )
          !! $spec.starts-with(">" | "<")
            ?? self.bless(
                 :comperator($spec.substr(0,1)), :version($spec.substr(1))
               )
            !! self.bless(:version($spec))
    }

    multi method ACCEPTS(VersionConstraint:D: Version(Cool) $topic --> Bool:D) {
        &!op($topic, $!version)
    }

    multi method Str(VersionConstraint:D:) {
        &!op =:= &whatever
          ?? "*"
          !! &!op =:= &[==]
            ?? ~$!version
            !! "$!comperator$!version"
    }
}

#- VERS ------------------------------------------------------------------------
class VERS:ver<0.0.1>:auth<zef:lizmat> {
    has Str $.scheme = 'vers';
    has Str $.type        is required;
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
            my $type = $remainder.substr(0,$index).lc;
            die "Invalid type: $type" unless is-identifier($type);  # XXX check for known type

            %args<type> = $type;

            $remainder .= substr($index + 1);
        }
        else {
            die "Must have a type specified";
        }

        %args<constraints> :=
          check-constraints $remainder.split("|", :skip-empty);

        %args
    }

    # Check the validity of the constraints
    sub check-constraints(@constraints is copy) {

        @constraints = @constraints.map({
            $_ ~~ VersionConstraint ?? $_ !! VersionConstraint.new($_)
        }).sort(*.version);

        die "Must have at least one version" unless @constraints;

        if @constraints.head.version eq '*' {
            die "Can only have '*' as the only version constraint"
              unless @constraints == 1;
        }
 
        if @constraints>>.version.repeated -> @repeated {
            die "Version '@repeated.join("', '")' occurred more than once";
        }

dd @constraints;
        # Weed out any sequential > >= < <=
        @constraints = @constraints
          .reverse
          .squish(:as(*.comperator.substr(0,1)))
          .reverse;
dd @constraints;

        my $comperator = @constraints.head.comperator;
        for 1..^@constraints -> $i {
            my $next := @constraints[$i].comperator;

            sub check-next(@oks) {
                die "Comperator '$next' can not follow '$comperator' in @constraints.join(" | ")"
                  unless $next eq any(@oks);
            }

            if $comperator eq '==' {
                check-next « == > >= »;
            }
            elsif $comperator eq "<" | "<=" {
                check-next « > >= »;
            }
            elsif $comperator eq ">" | ">=" {
                check-next « < <= »;
            }
            $comperator = $next;
        }

        @constraints
    }

    multi method new(VERS:) {
        %_<constraints> := check-constraints($_) with %_<constraints>;
        self.bless: |%_
    }
    multi method new(VERS: Str:D $spec) {
        self.bless: |hashify($spec)
    }

    method from-identity(VERS: Str:D $id) {
        self.bless(
          :type<raku>,
          :constraints(VersionConstraint.new(
            :version(version($id) // "*".Version)
          ))
        )
    }

    multi method Str( VERS:D:) { "$!scheme:$!type/@!constraints.join(" | ")" }
    multi method gist(VERS:D:) { self.Str }

    method CALL-ME(Str:D $spec --> Bool:D) { (try hashify($spec)).Bool }

    multi method ACCEPTS(VERS:D: Version(Cool) $topic --> Bool:D) {
        $topic ~~ any(@!constraints)
    }
}

# vim: expandtab shiftwidth=4
