#security group module enforces least-privilege access using dynamic rule generation and security-group referencing
#1. creates all sg
#2. applies least-privilege ingress rules
#3. manages sg-to-sg communication dynamically
#4. avoids circular dependencies


# --- STEP 1: THE "BOXES" (Resource Splitting) ---
#creates empty SG containers first
# -> prevents circular dependency errors in AWS, every grp has an ID before telling them who they are allowed to talk to (SGs references each other)
resource "aws_security_group" "this" {
  for_each    = var.sg_configs #creates one SG for every key in sg_configs map
  name        = "${var.name_prefix}-${each.key}"
  description = each.value.description
  vpc_id      = var.vpc_id

  #standard outbound rule allowing all traffic from the instances to the internet
  egress { 
    from_port   = var.service_ports["any"]        # 0
    to_port     = var.service_ports["any"]        # 0
    protocol    = var.network_config["any_proto"] # "-1"
    cidr_blocks = [var.network_config["all_ips"]] # "0.0.0.0/0"
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-${each.key}" })
} #result = empty boxes in AWS that have an ID but no firewall rules inside them yet

# --- STEP 2: THE "SIMPLIFIED LIST" (Flattening) ---
#takes all the nested rules inside the grps and turns them into a single flat list
#-> tf cant loop thru lists inside of lists, use flat list to create every rule at once
locals {
  rules_list = flatten([ #loops through every SG and then loops through every rule inside that group to create a single flat list of rule objects
    for sg_key, sg_data in var.sg_configs : [ #goes thru every SG defined in the map to see what rules belong
      for idx, rule in sg_data.ingress_rules : { #looks at every individual rule inside the ingress_rule list
        id           = "${sg_key}-rule-${idx}"
        parent_sg_id = aws_security_group.this[sg_key].id
        from_port    = rule.from_port
        to_port      = rule.to_port
        protocol     = rule.protocol
        cidr_blocks  = rule.cidr_blocks

        #dynamic lookup: automatically finds the physical AWS ID of a group to not hardcode IDs
        source_id    = rule.source_security_group_id != null ? aws_security_group.this[rule.source_security_group_id].id : null
      }
    ]
  ])
}


# --- STEP 3: ATTACHING THE RULES ---
#takes the flat list and tells AWS to put the rules into the boxes
# 3. Attach rules to the containers (This breaks the circular dependency)
resource "aws_security_group_rule" "ingress" {
  for_each = { for r in local.rules_list : r.id => r } #creates 1 individual rule resource for every item in the list

  type                     = "ingress"
  security_group_id        = each.value.parent_sg_id #to know which box to go into
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  cidr_blocks              = each.value.cidr_blocks
  source_security_group_id = each.value.source_id #to know which box is allowed to talk to it
}