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

#- VersionConstraint -----------------------------------------------------------
class VersionConstraint:ver<0.0.1>:auth<zef:lizmat> {
    has $.op      is built(:bind);
    has $.version is built(:bind);

    submethod TWEAK(:$version is copy --> Nil) {

        if $!op {
            $!op := ::('&infix:«' ~ $!op ~ '»') unless $!op ~~ Callable;
        }

        if $version ~~ Version {
            $!op := &whatever if $version.whatever;
            $!op := &[>=]     if $version.plus;
        }
        elsif $version {
            $version = decode($version);
            $!op := $version eq '*' ?? &whatever !! &[==] unless $!op;

            # Convert to Version object to get correct semantics
            $!version := $version.Version;
        }
        else {
            die "Must have at least a version specified";
        }
    }

    multi method new(VersionConstraint: Str() $spec) {
        $spec.starts-with(">=" | "<=" | "!=")
          ?? self.bless(:op($spec.substr(0,2)), :version($spec.substr(2)))
          !! $spec.starts-with(">" | "<")
            ?? self.bless(:op($spec.substr(0,1)), :version($spec.substr(1)))
            !! self.bless(:version($spec))
    }

    multi method ACCEPTS(VersionConstraint:D: Version(Cool) $topic --> Bool:D) {
        $!op($topic, $!version)
    }

    multi method Str(VersionConstraint:D:) {
        $!op =:= &whatever
          ?? "*"
          !! $!op =:= &[==]
            ?? ~$!version
            !! "$!op.gist.substr(8, *-1)$!version"
    }
}

#- VERS ------------------------------------------------------------------------
class VERS:ver<0.0.1>:auth<zef:lizmat> {
    has Str $.scheme = 'vers';
    has Str $.type        is required;
    has     @.constraints is required is List;

    # Create an argument hash for the given Package URL
    method !hashify(Str:D $spec) {
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

        die "Must have at least one version" unless $remainder;

        my @constraints = $remainder.split("|").map: {
            VersionConstraint.new($_) if $_
        }

        # XXX check sanity / optimize list of constraints

        %args<constraints> := @constraints.List;

        %args
    }

    multi method new(VERS: Str:D $spec) {
        self.bless: |self!hashify($spec)
    }

    submethod TWEAK() {
        die "All constraints must VersionConstraint objects"
          unless @!constraints.are(VersionConstraint);
    }

    method from-identity(VERS: Str:D $id) {
        self.bless(:type<raku>, :constraints(version($id) // "*".Version))
    }

    multi method Str( VERS:D:) { "$!scheme:$!type/@!constraints.join("|")" }
    multi method gist(VERS:D:) { self.Str }

    method CALL-ME(Str:D $spec --> Bool:D) { (try self!hashify($spec)).Bool }

    multi method ACCEPTS(VERS:D: Version(Cool) $topic --> Bool:D) {
#        $!op($topic, $!version)
    }
}

say "1.04" ~~ VERS.new("vers:raku/ 1.01| >1.03");

# vim: expandtab shiftwidth=4
