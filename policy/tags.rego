package main

import rego.v1

# Tags que todo recurso com suporte a tags precisa ter.
required_tags := {"Project", "Environment"}

# Só o que o plan vai criar e que tem o atributo "tags".
# (versioning, policy etc. não têm tags e ficam de fora)
taggable(rc) if {
	"create" in rc.change.actions
	"tags" in object.keys(rc.change.after)
}

# tags_all inclui as default_tags do provider. Se ela ainda é desconhecida
# (ausente no plan), vale "tags". Se nenhuma é objeto, não há tag nenhuma.
effective_tags(rc) := tags if {
	tags := rc.change.after.tags_all
	is_object(tags)
} else := tags if {
	tags := rc.change.after.tags
	is_object(tags)
} else := {}

deny contains msg if {
	some rc in input.resource_changes
	taggable(rc)
	some tag in required_tags
	not tag in object.keys(effective_tags(rc))
	msg := sprintf("%s precisa da tag %s", [rc.address, tag])
}
