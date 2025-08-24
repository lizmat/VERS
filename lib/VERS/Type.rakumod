use Version::Raku:ver<0.0.1+>:auth<zef:lizmat>;
use Version::Repology:ver<0.0.5+>:auth<zef:lizmat>;
use Version::Semver:ver<0.0.1+>:auth<zef:lizmat>;

#- VERS::Type ------------------------------------------------------------------
class VERS::Type:ver<0.0.4>:auth<zef:lizmat> {

    proto method Version(|) {*}
    multi method Version(VERS::Type:)          { Version::Semver      }
    multi method Version(VERS::Type: Str:D $_) { self.Version.new($_) }

    multi method Str(VERS::Type:) { self.^name.subst("VERS::") }

    method CALL-ME(VERS::Type:U: Str() $_) { ::("VERS::$_") }

    method denatify(VERS::Type: Str:D $_) { $_ }
}

#- A ---------------------------------------------------------------------------
class VERS::alpm is VERS::Type {
    multi method Version(VERS::alpm: Str() $_) {
        Version::Repology.new($_,
          :any-is-patch,
          :no-leading-zero
        )
    }
}

class VERS::apk is VERS::Type {
    multi method Version(VERS::apk: Str() $_) {
        Version::Repology.new($_,
          :p-is-patch,
          :leading-zero-alpha,
          :additional-special(%(r => post-release)),
        )
    }
}

#- B ---------------------------------------------------------------------------
class VERS::bitbucket is VERS::Type {
}

class VERS::bitnami is VERS::Type {
}

#- C ---------------------------------------------------------------------------
class VERS::cargo is VERS::Type {
}

class VERS::cocoapods is VERS::Type {
}

class VERS::composer is VERS::Type {
}

class VERS::conan is VERS::Type {
}

class VERS::conda is VERS::Type {
}

class VERS::cpan is VERS::Type {
}

class VERS::cran is VERS::Type {
}

#- D ---------------------------------------------------------------------------
class VERS::deb is VERS::Type {
}

class VERS::docker is VERS::Type {
}

#- G ---------------------------------------------------------------------------
class VERS::gem is VERS::Type {
    method denatify(VERS::gem: Str:D $_) {
        if .starts-with("~>") {
            my $version  := .substr(2);
            my @parts = $version.split(/ \W+ /, :v);
            @parts.pop; @parts.pop;  # lose last delimiter + part
            @parts.push: @parts.pop.Int + 1;
            ">=$version|<@parts.join"
        }
        else {
            $_
        }
    }
}

class VERS::generic is VERS::Type {
}

class VERS::github is VERS::Type {
}

class VERS::golang is VERS::Type {
}

#- H ---------------------------------------------------------------------------
class VERS::hackage is VERS::Type {
}

class VERS::hex is VERS::Type {
}

class VERS::huggingface is VERS::Type {
}

#- L ---------------------------------------------------------------------------
class VERS::luarocks is VERS::Type {
}

#- M ---------------------------------------------------------------------------
class VERS::maven is VERS::Type {
}

class VERS::mlflow is VERS::Type {
}

#- N ---------------------------------------------------------------------------
class VERS::npm is VERS::Type {
}

class VERS::nuget is VERS::Type {
}

#- O ---------------------------------------------------------------------------
class VERS::oci is VERS::Type {
}

#- P ---------------------------------------------------------------------------
class VERS::pub is VERS::Type {
}

class VERS::pypi is VERS::Type {
}

#- Q ---------------------------------------------------------------------------
class VERS::qpkg is VERS::Type {
}

#- R ---------------------------------------------------------------------------
class VERS::raku is VERS::Type {
    multi method Version(VERS::raku:) { Version::Raku }

    method denatify(VERS::raku: Str:D $spec) {
        die "Must have some version string" unless $spec;

        my str @parts = $spec.split(".");
        with @parts.first(*.starts-with('*'), :k) -> $index {
            $index ?? ">=@parts.head($index).join('.')" !! '*'
        }
        orwith @parts.first(*.ends-with('+'), :k) -> $index {
            ">=@parts.head($index + 1).join('.').chop()"
        }
        else {
            $spec
        }
    }
}

class VERS::rpm is VERS::Type {
}

#- S ---------------------------------------------------------------------------
class VERS::swid is VERS::Type {
}

# vim: expandtab shiftwidth=4
