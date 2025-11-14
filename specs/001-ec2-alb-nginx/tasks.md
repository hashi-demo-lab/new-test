# Tasks: EC2 Web Infrastructure with Application Load Balancer

**Input**: Design documents from `/workspace/specs/001-ec2-alb-nginx/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Tests are NOT explicitly requested in the specification - focusing on implementation tasks only.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Project Infrastructure)

**Purpose**: Initialize Terraform project structure and tooling

- [ ] T001 Create Terraform project file structure in /workspace/ directory
- [ ] T002 [P] Initialize .gitignore with Terraform artifacts (.terraform/, *.tfstate, *.tfvars, .terraform.lock.hcl)
- [ ] T003 [P] Install and configure pre-commit framework
- [ ] T004 [P] Create .pre-commit-config.yaml with terraform_fmt, terraform_docs, terraform_validate, tflint, checkov hooks
- [ ] T005 Configure git hooks in .git/hooks/pre-commit
- [ ] T006 [P] Create README.md template for terraform-docs auto-generation

---

## Phase 2: Foundational (Terraform Core Configuration)

**Purpose**: Core Terraform configuration that MUST be complete before ANY infrastructure modules can be instantiated

**⚠️ CRITICAL**: No infrastructure provisioning can begin until this phase is complete

- [ ] T007 Create versions.tf with Terraform >= 1.8 requirement and AWS provider ~> 5.0 constraint in /workspace/versions.tf
- [ ] T008 [P] Create providers.tf with AWS provider configuration for ap-southeast-2 region in /workspace/providers.tf
- [ ] T009 [P] Create locals.tf with common tags and naming conventions in /workspace/locals.tf
- [ ] T010 [P] Create variables.tf with region, instance_type, environment, and common_tags variables in /workspace/variables.tf
- [ ] T011 [P] Create outputs.tf with output structure (alb_dns_name, alb_zone_id, instance_ids, instance_private_ips) in /workspace/outputs.tf
- [ ] T012 Create override.tf with HCP Terraform cloud backend configuration (organization: hashi-demos-apj, workspace: sandbox_ec2new-test, project: sandbox) in /workspace/override.tf
- [ ] T013 [P] Create sandbox.auto.tfvars.example with example variable values in /workspace/sandbox.auto.tfvars.example
- [ ] T014 [P] Create sandbox.auto.tfvars with actual testing variable values in /workspace/sandbox.auto.tfvars

**Checkpoint**: Terraform core configuration ready - infrastructure module instantiation can now begin

---

## Phase 3: User Story 1 - Deploy High-Availability Web Infrastructure (Priority: P1) 🎯 MVP

**Goal**: Deploy 2x EC2 instances with Nginx across 2 availability zones, fronted by an internet-facing Application Load Balancer, using existing default VPC

**Independent Test**: Deploy infrastructure and verify:
1. Instances provisioned in 2 separate AZs (ap-southeast-2a, ap-southeast-2b)
2. HTTP requests to ALB DNS endpoint return successful responses
3. Traffic distributes across both AZ instances

### Data Sources for User Story 1

- [ ] T015 [P] [US1] Add data source for default VPC lookup in /workspace/main.tf
- [ ] T016 [P] [US1] Add data source for default VPC subnets filtered by ap-southeast-2a and ap-southeast-2b AZs in /workspace/main.tf

### Security Groups for User Story 1

- [ ] T017 [P] [US1] Create ALB security group module block with ingress 0.0.0.0/0:80,443 and egress all in /workspace/main.tf
- [ ] T018 [P] [US1] Create EC2 security group module block with ingress from ALB security group on ports 80,443 and egress 0.0.0.0/0:443,80 in /workspace/main.tf

### Application Load Balancer for User Story 1

- [ ] T019 [US1] Create ALB module block with internet-facing scheme, HTTP listener on port 80, target group configuration, and health check settings (interval: 10s, timeout: 5s, unhealthy_threshold: 2, path: /health) in /workspace/main.tf

### Nginx User Data Script for User Story 1

- [ ] T020 [US1] Create user_data.sh script with Nginx installation, self-signed SSL certificate generation (365 days validity), and HTTP/HTTPS server configuration in /workspace/user_data.sh
- [ ] T021 [US1] Configure Nginx HTTP server block with /health endpoint (return 200) and independent operation (no redirect) in /workspace/user_data.sh
- [ ] T022 [US1] Add comprehensive error handling and logging (exec > tee /var/log/user-data.log) to user_data.sh

### IAM Instance Profile for User Story 1

- [ ] T023 [US1] Create IAM role resource with AssumeRole policy for EC2 service in /workspace/main.tf
- [ ] T024 [P] [US1] Attach AmazonSSMManagedInstanceCore managed policy to IAM role in /workspace/main.tf
- [ ] T025 [P] [US1] Create custom CloudWatch Logs IAM policy (scoped to /aws/ec2/nginx/* log group) and attach to IAM role in /workspace/main.tf
- [ ] T026 [US1] Create IAM instance profile resource referencing the IAM role in /workspace/main.tf

### EC2 Instances for User Story 1

- [ ] T027 [US1] Create EC2 instance module block for AZ1 (ap-southeast-2a) with t3.small type, AMI from SSM parameter, user_data templatefile, IAM instance profile, target group attachment, and EC2 security group in /workspace/main.tf
- [ ] T028 [US1] Create EC2 instance module block for AZ2 (ap-southeast-2b) with identical configuration to AZ1 except subnet in /workspace/main.tf

### Output Values for User Story 1

- [ ] T029 [P] [US1] Add alb_dns_name output referencing module.alb.dns_name in /workspace/outputs.tf
- [ ] T030 [P] [US1] Add alb_zone_id output referencing module.alb.zone_id in /workspace/outputs.tf
- [ ] T031 [P] [US1] Add instance_ids output as list containing both EC2 instance IDs in /workspace/outputs.tf
- [ ] T032 [P] [US1] Add instance_private_ips output as list containing both EC2 private IPs in /workspace/outputs.tf
- [ ] T033 [P] [US1] Add alb_target_group_arns output referencing ALB target groups in /workspace/outputs.tf

### Validation for User Story 1

- [ ] T034 [US1] Run terraform init to initialize providers and modules in /workspace/
- [ ] T035 [US1] Run terraform validate to check syntax and configuration in /workspace/
- [ ] T036 [US1] Run terraform fmt -recursive to format all Terraform files in /workspace/
- [ ] T037 [US1] Run pre-commit run --all-files to execute all configured hooks in /workspace/
- [ ] T038 [US1] Fix any tfsec or checkov security findings reported by pre-commit hooks

**Checkpoint**: At this point, User Story 1 infrastructure should be fully deployable and testable independently via terraform plan/apply

---

## Phase 4: User Story 2 - Secure HTTPS Access (Priority: P2)

**Goal**: Enable HTTPS encryption on the ALB listener with self-signed SSL certificates, operating independently from HTTP listener

**Independent Test**:
1. Make HTTPS request to ALB DNS endpoint on port 443
2. Verify SSL/TLS handshake completes successfully
3. Verify HTTP:80 requests still served independently (no redirect)

### HTTPS Listener Configuration for User Story 2

- [ ] T039 [US2] Add HTTPS listener (port 443) to ALB module block with TLS policy ELBSecurityPolicy-TLS13-1-2-2021-06 in /workspace/main.tf
- [ ] T040 [US2] Create AWS ACM certificate resource for self-signed certificate or reference certificate ARN variable in /workspace/main.tf
- [ ] T041 [US2] Configure HTTPS listener default action to forward to nginx_instances target group in /workspace/main.tf

### Nginx HTTPS Configuration for User Story 2

- [ ] T042 [US2] Update user_data.sh to configure Nginx HTTPS server block with listen 443 ssl http2 in /workspace/user_data.sh
- [ ] T043 [US2] Configure Nginx SSL certificate paths (/etc/nginx/ssl/nginx-selfsigned.crt and .key) in /workspace/user_data.sh
- [ ] T044 [US2] Set Nginx SSL protocols to TLSv1.2 and TLSv1.3 with secure ciphers in /workspace/user_data.sh
- [ ] T045 [US2] Add /health endpoint to HTTPS server block (return 200 "healthy") in /workspace/user_data.sh

### Validation for User Story 2

- [ ] T046 [US2] Run terraform validate to verify HTTPS listener configuration in /workspace/
- [ ] T047 [US2] Run terraform plan to preview HTTPS changes without affecting existing HTTP infrastructure in /workspace/
- [ ] T048 [US2] Verify pre-commit hooks pass with HTTPS configuration changes in /workspace/

**Checkpoint**: At this point, both User Story 1 (HTTP) and User Story 2 (HTTPS) should work independently with no redirect

---

## Phase 5: User Story 3 - Fault Tolerance and Recovery (Priority: P3)

**Goal**: Validate high-availability design by testing instance and AZ failure scenarios with automatic recovery

**Independent Test**:
1. Stop one EC2 instance
2. Verify ALB detects failure within 20 seconds (2 failed health checks at 10s interval)
3. Verify traffic routes 100% to healthy instance
4. Restart failed instance
5. Verify ALB re-adds instance after 2 successful health checks

### Health Check Validation for User Story 3

- [ ] T049 [US3] Verify ALB target group health_check block has interval=10, timeout=5, unhealthy_threshold=2 in /workspace/main.tf
- [ ] T050 [US3] Verify health check path is /health and protocol is HTTP in /workspace/main.tf
- [ ] T051 [US3] Verify health check matcher is "200" for successful responses in /workspace/main.tf

### Monitoring Configuration for User Story 3

- [ ] T052 [P] [US3] Add CloudWatch alarm for ALB UnhealthyTargetCount metric (optional, for observability) in /workspace/main.tf
- [ ] T053 [P] [US3] Add CloudWatch alarm for ALB 5XX error rate (optional, for observability) in /workspace/main.tf

### Documentation for User Story 3

- [ ] T054 [US3] Document failover testing procedure in quickstart.md verification section
- [ ] T055 [US3] Document health check detection times (20s failure detection, 60s total removal) in quickstart.md
- [ ] T056 [US3] Document expected behavior when both instances unhealthy (503 Service Unavailable) in quickstart.md

**Checkpoint**: All user stories should now be independently functional - infrastructure validates high availability design

---

## Phase 6: Polish & Deployment Preparation

**Purpose**: Final improvements, documentation, and deployment readiness

### Documentation

- [ ] T057 [P] Run terraform-docs to auto-generate README.md from Terraform configuration in /workspace/
- [ ] T058 [P] Update README.md with deployment prerequisites (AWS credentials, HCP Terraform access, default VPC requirements) in /workspace/README.md
- [ ] T059 [P] Document HCP Terraform workspace configuration (organization, project, workspace naming) in /workspace/README.md
- [ ] T060 [P] Add usage examples to README.md showing terraform init, validate, plan, apply workflow in /workspace/README.md

### Pre-Deployment Validation

- [ ] T061 Run terraform fmt -check to verify all files formatted in /workspace/
- [ ] T062 Run terraform validate to final syntax check in /workspace/
- [ ] T063 Run pre-commit run --all-files for final quality and security checks in /workspace/
- [ ] T064 Review checkov findings and document any accepted risks in /workspace/
- [ ] T065 Review tfsec findings and ensure no high-severity security issues in /workspace/

### HCP Terraform Workspace Setup

- [ ] T066 Verify HCP Terraform organization "hashi-demos-apj" is accessible
- [ ] T067 Verify HCP Terraform project "sandbox" exists
- [ ] T068 Verify workspace "sandbox_ec2new-test" is configured with VCS connection to 001-ec2-alb-nginx branch
- [ ] T069 Verify workspace auto-apply is DISABLED (manual approval required for safety)
- [ ] T070 Create workspace variables from sandbox.auto.tfvars for testing

### Ephemeral Testing

- [ ] T071 Create ephemeral test workspace with naming pattern "test-ec2-alb-nginx-<timestamp>"
- [ ] T072 Configure ephemeral workspace with auto-apply ENABLED and auto-destroy after 2 hours
- [ ] T073 Create workspace variables in ephemeral workspace from sandbox.auto.tfvars
- [ ] T074 Run terraform plan in ephemeral workspace and analyze output
- [ ] T075 Monitor terraform apply in ephemeral workspace for successful completion
- [ ] T076 Validate created infrastructure (HTTP/HTTPS accessibility, health checks, traffic distribution)
- [ ] T077 Destroy ephemeral workspace after successful validation

### Final Deployment to Sandbox

- [ ] T078 Review terraform plan in HCP Terraform UI for sandbox_ec2new-test workspace
- [ ] T079 Confirm resource count and configuration matches expectations
- [ ] T080 Execute terraform apply via HCP Terraform UI with manual approval
- [ ] T081 Monitor deployment progress (estimated 5-7 minutes)
- [ ] T082 Retrieve outputs (alb_dns_name, instance_ids) from terraform output
- [ ] T083 Run verification tests from quickstart.md (HTTP access, HTTPS access, health checks, traffic distribution)
- [ ] T084 Document deployment results including ALB DNS endpoint and instance IDs

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational phase completion - Core infrastructure deployment
- **User Story 2 (Phase 4)**: Depends on User Story 1 completion - Adds HTTPS to existing HTTP infrastructure
- **User Story 3 (Phase 5)**: Depends on User Story 1 AND 2 completion - Validates complete infrastructure
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories (MVP)
- **User Story 2 (P2)**: Depends on User Story 1 - Extends ALB with HTTPS listener
- **User Story 3 (P3)**: Depends on User Story 1 and 2 - Validates fault tolerance of complete infrastructure

### Within Each User Story

**User Story 1 (High-Availability Infrastructure)**:
1. Data sources and security groups (parallel)
2. ALB module (depends on security groups)
3. User data script and IAM (parallel)
4. EC2 instances (depends on ALB, IAM, user data)
5. Outputs and validation (depends on all infrastructure)

**User Story 2 (HTTPS Access)**:
1. HTTPS listener and certificate (parallel)
2. Nginx HTTPS configuration
3. Validation

**User Story 3 (Fault Tolerance)**:
1. Health check validation
2. Monitoring configuration (optional, parallel)
3. Documentation

### Parallel Opportunities

**Phase 1 (Setup)**:
- T002, T003, T004, T006 can run in parallel (different files)

**Phase 2 (Foundational)**:
- T008, T009, T010, T011, T013, T014 can run in parallel (different files)

**Phase 3 (User Story 1)**:
- T015, T016 (data sources) can run in parallel
- T017, T018 (security groups) can run in parallel
- T024, T025 (IAM policies) can run in parallel
- T029, T030, T031, T032, T033 (outputs) can run in parallel

**Phase 5 (User Story 3)**:
- T052, T053 (CloudWatch alarms) can run in parallel

**Phase 6 (Polish)**:
- T057, T058, T059, T060 (documentation) can run in parallel

---

## Parallel Example: User Story 1 Core Infrastructure

```bash
# Launch data sources together:
Task T015: "Add default VPC data source in /workspace/main.tf"
Task T016: "Add default VPC subnets data source in /workspace/main.tf"

# Launch security groups together:
Task T017: "Create ALB security group module in /workspace/main.tf"
Task T018: "Create EC2 security group module in /workspace/main.tf"

# Launch IAM policies together:
Task T024: "Attach AmazonSSMManagedInstanceCore in /workspace/main.tf"
Task T025: "Create CloudWatch Logs policy in /workspace/main.tf"

# Launch all outputs together:
Task T029: "Add alb_dns_name output in /workspace/outputs.tf"
Task T030: "Add alb_zone_id output in /workspace/outputs.tf"
Task T031: "Add instance_ids output in /workspace/outputs.tf"
Task T032: "Add instance_private_ips output in /workspace/outputs.tf"
Task T033: "Add alb_target_group_arns output in /workspace/outputs.tf"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T006)
2. Complete Phase 2: Foundational (T007-T014) - CRITICAL BLOCKER
3. Complete Phase 3: User Story 1 (T015-T038)
4. **STOP and VALIDATE**: Test User Story 1 independently
   - Verify HTTP access via ALB
   - Verify traffic distribution across both AZs
   - Verify health checks functioning
5. Deploy to ephemeral workspace for testing
6. Deploy to sandbox workspace

**At this point, you have a working MVP**: High-availability web infrastructure with HTTP access

### Incremental Delivery

1. **Foundation** (Phase 1-2) → Terraform project structure ready
2. **MVP** (Phase 3) → HTTP infrastructure deployed and validated
3. **HTTPS** (Phase 4) → Secure access added
4. **Validation** (Phase 5) → Fault tolerance verified
5. **Production Ready** (Phase 6) → Documentation complete, deployed to sandbox

Each phase adds value without breaking previous work.

### Cost Optimization Notes

- Ephemeral workspaces auto-destroy after 2 hours to minimize costs
- Total infrastructure cost: ~$47-55/month (within $50 budget)
- 2x t3.small instances: ~$32/month
- 1x ALB: ~$17/month
- Minimal data transfer: ~$1-2/month

---

## Notes

- **[P] tasks** = different files, no dependencies, can run in parallel
- **[Story] label** maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each logical group of tasks
- Stop at any checkpoint to validate story independently
- Run `terraform validate` frequently to catch configuration errors early
- Use pre-commit hooks to enforce code quality and security before commits
- Document any security findings accepted (checkov, tfsec) with justification
