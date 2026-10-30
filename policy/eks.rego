package main

import rego.v1

redes_abertas := {"0.0.0.0/0", "::/0"}

# O endpoint público do EKS só pode ser alcançado a partir de CIDRs definidos, nunca da internet inteira.
deny contains msg if {
	some rc in input.resource_changes
	"create" in rc.change.actions
	rc.type == "aws_eks_cluster"
	some vpc_config in rc.change.after.vpc_config
	vpc_config.endpoint_public_access == true
	some cidr in vpc_config.public_access_cidrs
	cidr in redes_abertas
	msg := sprintf("%s libera o endpoint público do cluster para %s", [rc.address, cidr])
}

# O cluster usa access entries; o ConfigMap aws-auth não deve ser o único modo de autenticação.
deny contains msg if {
	some rc in input.resource_changes
	"create" in rc.change.actions
	rc.type == "aws_eks_cluster"
	some acesso in rc.change.after.access_config
	acesso.authentication_mode == "CONFIG_MAP"
	msg := sprintf("%s usa só o ConfigMap aws-auth; use API ou API_AND_CONFIG_MAP", [rc.address])
}

# Sem enableNetworkPolicy, a NetworkPolicy é aceita pela API e ignorada pelo CNI.
deny contains msg if {
	some rc in input.resource_changes
	"create" in rc.change.actions
	rc.type == "aws_eks_addon"
	rc.change.after.addon_name == "vpc-cni"
	not network_policy_ligada(rc.change.after)
	msg := sprintf("%s: o vpc-cni precisa de enableNetworkPolicy = \"true\"", [rc.address])
}

network_policy_ligada(addon) if {
	valores := json.unmarshal(addon.configuration_values)
	valores.enableNetworkPolicy == "true"
}

# Nós em Spot só em laboratório; o grupo precisa ao menos de 2 nós para o PDB fazer sentido.
deny contains msg if {
	some rc in input.resource_changes
	"create" in rc.change.actions
	rc.type == "aws_eks_node_group"
	some escala in rc.change.after.scaling_config
	escala.desired_size < 2
	msg := sprintf("%s tem menos de 2 nós desejados", [rc.address])
}
