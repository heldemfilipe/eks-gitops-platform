package main

import rego.v1

# Policies IAM em linha ou gerenciadas (o campo "policy" é um JSON em texto).
policy_docs contains doc if {
	some rc in input.resource_changes
	"create" in rc.change.actions
	rc.type in {"aws_iam_role_policy", "aws_iam_policy"}
	doc := {"address": rc.address, "json": json.unmarshal(rc.change.after.policy)}
}

acoes(stmt) := a if {
	is_array(stmt.Action)
	a := stmt.Action
} else := [stmt.Action]

recursos(stmt) := r if {
	is_array(stmt.Resource)
	r := stmt.Resource
} else := [stmt.Resource]

statements(doc) := s if {
	is_array(doc.json.Statement)
	s := doc.json.Statement
} else := [doc.json.Statement]

# Nenhuma policy pode permitir todas as ações.
deny contains msg if {
	some doc in policy_docs
	some stmt in statements(doc)
	stmt.Effect == "Allow"
	"*" in acoes(stmt)
	msg := sprintf("%s permite Action \"*\"", [doc.address])
}

# Ações do Secrets Manager nunca com Resource "*" nem com ação curinga: segredo se libera por prefixo.
deny contains msg if {
	some doc in policy_docs
	some stmt in statements(doc)
	stmt.Effect == "Allow"
	some acao in acoes(stmt)
	startswith(acao, "secretsmanager:")
	"*" in recursos(stmt)
	msg := sprintf("%s libera %s em todos os segredos (Resource \"*\")", [doc.address, acao])
}

deny contains msg if {
	some doc in policy_docs
	some stmt in statements(doc)
	stmt.Effect == "Allow"
	"secretsmanager:*" in acoes(stmt)
	msg := sprintf("%s usa secretsmanager:* (liste as ações)", [doc.address])
}

# Role de Pod Identity só confia em pods.eks.amazonaws.com.
deny contains msg if {
	some rc in input.resource_changes
	"create" in rc.change.actions
	rc.type == "aws_iam_role"
	trust := json.unmarshal(rc.change.after.assume_role_policy)
	some stmt in object.get(trust, "Statement", [])
	stmt.Principal.Service == "ecs-tasks.amazonaws.com"
	msg := sprintf("%s é uma role de pod mas confia em ecs-tasks.amazonaws.com", [rc.address])
}
