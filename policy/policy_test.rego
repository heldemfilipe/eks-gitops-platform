package main

import rego.v1

# Testes das políticas. Rodar com: opa test policy/ -v
# Cada teste monta um plan mínimo, no formato do `terraform show -json`, e confere as mensagens.

tags_ok := {"Project": "eks-gitops-platform", "Environment": "lab"}

t_raiz(tipo, after) := {
	"address": sprintf("%s.this", [tipo]),
	"type": tipo,
	"change": {"actions": ["create"], "after": after},
}

t_plano(recursos) := {"resource_changes": recursos}

# --- tags ---

test_tags_completas_passam if {
	r := t_raiz("aws_vpc", {"tags": tags_ok, "tags_all": tags_ok})
	count(deny) == 0 with input as t_plano([r])
}

test_sem_environment_e_negado if {
	t := {"Project": "x"}
	r := t_raiz("aws_vpc", {"tags": t, "tags_all": t})
	"aws_vpc.this precisa da tag Environment" in deny with input as t_plano([r])
}

# --- endpoint do EKS ---

cluster(cidrs, modo) := t_raiz("aws_eks_cluster", {
	"tags": tags_ok,
	"tags_all": tags_ok,
	"vpc_config": [{"endpoint_public_access": true, "public_access_cidrs": cidrs}],
	"access_config": [{"authentication_mode": modo}],
})

test_endpoint_restrito_passa if {
	count(deny) == 0 with input as t_plano([cluster(["203.0.113.10/32"], "API")])
}

test_endpoint_aberto_e_negado if {
	"aws_eks_cluster.this libera o endpoint público do cluster para 0.0.0.0/0" in deny with input as t_plano([cluster(["0.0.0.0/0"], "API")])
}

test_so_configmap_e_negado if {
	"aws_eks_cluster.this usa só o ConfigMap aws-auth; use API ou API_AND_CONFIG_MAP" in deny with input as t_plano([cluster(["203.0.113.10/32"], "CONFIG_MAP")])
}

# --- vpc-cni ---

cni(valores) := t_raiz("aws_eks_addon", {
	"tags": tags_ok,
	"tags_all": tags_ok,
	"addon_name": "vpc-cni",
	"configuration_values": valores,
})

test_cni_com_network_policy_passa if {
	count(deny) == 0 with input as t_plano([cni("{\"enableNetworkPolicy\":\"true\"}")])
}

test_cni_sem_network_policy_e_negado if {
	"aws_eks_addon.this: o vpc-cni precisa de enableNetworkPolicy = \"true\"" in deny with input as t_plano([cni("{}")])
}

# --- nós ---

grupo(n) := t_raiz("aws_eks_node_group", {
	"tags": tags_ok,
	"tags_all": tags_ok,
	"scaling_config": [{"desired_size": n}],
})

test_dois_nos_passa if {
	count(deny) == 0 with input as t_plano([grupo(2)])
}

test_um_no_e_negado if {
	"aws_eks_node_group.this tem menos de 2 nós desejados" in deny with input as t_plano([grupo(1)])
}

# --- security group ---

test_ssh_aberto_e_negado if {
	r := t_raiz("aws_vpc_security_group_ingress_rule", {
		"tags": tags_ok,
		"tags_all": tags_ok,
		"cidr_ipv4": "0.0.0.0/0",
		"ip_protocol": "tcp",
		"from_port": 22,
		"to_port": 22,
	})
	"aws_vpc_security_group_ingress_rule.this expõe porta administrativa para 0.0.0.0/0" in deny with input as t_plano([r])
}

# --- IAM ---

politica(tipo, doc) := t_raiz(tipo, {"tags": tags_ok, "tags_all": tags_ok, "policy": json.marshal(doc)})

eso_ok := {"Version": "2012-10-17", "Statement": [{
	"Effect": "Allow",
	"Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
	"Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:eks-lab/*",
}]}

test_eso_restrito_passa if {
	count(deny) == 0 with input as t_plano([politica("aws_iam_role_policy", eso_ok)])
}

test_segredos_com_resource_curinga_e_negado if {
	doc := {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "secretsmanager:GetSecretValue", "Resource": "*"}]}
	"aws_iam_role_policy.this libera secretsmanager:GetSecretValue em todos os segredos (Resource \"*\")" in deny with input as t_plano([politica("aws_iam_role_policy", doc)])
}

test_action_curinga_e_negada if {
	doc := {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "*", "Resource": "arn:aws:s3:::x"}]}
	"aws_iam_role_policy.this permite Action \"*\"" in deny with input as t_plano([politica("aws_iam_role_policy", doc)])
}

test_secretsmanager_curinga_e_negado if {
	doc := {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": ["secretsmanager:*"], "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:eks-lab/*"}]}
	"aws_iam_role_policy.this usa secretsmanager:* (liste as ações)" in deny with input as t_plano([politica("aws_iam_role_policy", doc)])
}

test_policy_oficial_do_lbc_com_resource_curinga_em_ec2_passa if {
	doc := {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": ["ec2:DescribeVpcs"], "Resource": "*"}]}
	count(deny) == 0 with input as t_plano([politica("aws_iam_policy", doc)])
}

test_role_de_pod_que_confia_em_ecs_e_negada if {
	trust := {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": {"Service": "ecs-tasks.amazonaws.com"}, "Action": "sts:AssumeRole"}]}
	r := t_raiz("aws_iam_role", {"tags": tags_ok, "tags_all": tags_ok, "assume_role_policy": json.marshal(trust)})
	"aws_iam_role.this é uma role de pod mas confia em ecs-tasks.amazonaws.com" in deny with input as t_plano([r])
}
