use Version::Raku:ver<0.0.1+>:auth<zef:lizmat>;
use Version::Repology:ver<0.0.3+>:auth<zef:lizmat>;

#- VERS::Type ------------------------------------------------------------------
class VERS::Type:ver<0.0.3>:auth<zef:lizmat> {

    proto method Version(|) {*}
    multi method Version(VERS::Type:)          { Version::Repology         }
    multi method Version(VERS::Type: Str() $_) { Version::Repology.new($_) }

    multi method Str(VERS::Type:) { self.^name.subst("VERS::") }

    method CALL-ME(VERS::Type:U: Str() $_) { ::("VERS::$_") }
}

#- A ---------------------------------------------------------------------------
class VERS::alpm is VERS::Type {
}

class VERS::apk is VERS::Type {
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

    proto method Version(|) {*}
    multi method Version(VERS::raku:)    { Version::Raku         }
    multi method Version(VERS::raku: $_) { Version::Raku.new($_) }
}

class VERS::rpm is VERS::Type {
}

#- S ---------------------------------------------------------------------------
class VERS::swid is VERS::Type {
}

# vim: expandtab shiftwidth=4
