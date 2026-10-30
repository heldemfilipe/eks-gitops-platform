package main

import rego.v1

portas_admin := {22, 3389}

redes_abertas := {"0.0.0.0/0", "::/0"}

# Vale quando o protocolo é "-1" (todo o tráfego)...
expoe_admin(protocolo, _, _) if protocolo == "-1"

# ...ou quando o intervalo de portas cobre uma porta administrativa.
expoe_admin(_, de, ate) if {
	some porta in portas_admin
	de <= porta
	porta <= ate
}

# Regra separada (aws_vpc_security_group_ingress_rule).
deny contains msg if {
	some rc in input.resource_changes
	"create" in rc.change.actions
	rc.type == "aws_vpc_security_group_ingress_rule"
	regra := rc.change.after
	some cidr in {object.get(regra, "cidr_ipv4", null), object.get(regra, "cidr_ipv6", null)}
	cidr in redes_abertas
	expoe_admin(regra.ip_protocol, object.get(regra, "from_port", 0), object.get(regra, "to_port", 0))
	msg := sprintf("%s expõe porta administrativa para %s", [rc.address, cidr])
}

# Regra embutida no security group (bloco ingress).
deny contains msg if {
	some rc in input.resource_changes
	"create" in rc.change.actions
	rc.type == "aws_security_group"
	some regra in rc.change.after.ingress
	cidrs := array.concat(object.get(regra, "cidr_blocks", []), object.get(regra, "ipv6_cidr_blocks", []))
	some cidr in cidrs
	cidr in redes_abertas
	expoe_admin(regra.protocol, regra.from_port, regra.to_port)
	msg := sprintf("%s expõe porta administrativa para %s", [rc.address, cidr])
}
