# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL := /bin/bash

JOB_NAME ?= job
JOB_EMAIL ?= job@job.job

PYTHON3_INSTALLED = $(shell which python3 > /dev/null 2>&1; echo $$?)
MISE_INSTALLED = $(shell which mise > /dev/null 2>&1; echo $$?)
ASDF_INSTALLED = $(shell which asdf > /dev/null 2>&1; echo $$?)
GIT_USER_SET = $(shell git config --get user.name > /dev/null 2>&1; echo $$?)
GIT_EMAIL_SET = $(shell git config --get user.email > /dev/null 2>&1; echo $$?)

# ------------------------------------------------------------------------------
# Binaries
# ------------------------------------------------------------------------------

GO ?= go
GOLANGCI_LINT ?= golangci-lint
TEE ?= tee
GREP ?= grep
FIND ?= find
TERRAFORM ?= terraform
RM ?= rm -rf
TFLINT ?= tflint

# ------------------------------------------------------------------------------
# Variables — Golang
# ------------------------------------------------------------------------------

GO_TEST_DIRECTORIES ?= tests
GO_TEST_TIMEOUT ?= 2h
GO_TEST_READONLY_DIRECTORY ?= post_deploy_functional_readonly
TEST_RUN_ONLY_READONLY = #intentionally empty
TEST_RUN_EXCLUDE_READONLY = -v
GOLANGCI_LINT_CONFIG ?= .golangci.yaml
DISABLE_MAKE_CHECK_LINT ?= false
CURRENT_DIR = $(notdir $(shell pwd))

# If ARM_SUBSCRIPTION_ID is not already set by the environment, we'll try to use the `az` command
# to retrieve it. If `az` isn't found or not logged in, we'll silently continue here and catch
# that case elsewhere.
export ARM_SUBSCRIPTION_ID ?= $(shell command -v az >/dev/null 2>&1 && az account show 2>/dev/null | jq -r .id)

# ------------------------------------------------------------------------------
# Variables — Terraform module
# ------------------------------------------------------------------------------

ALL_TF_MODULES = $(shell $(call list_terraform_modules))
ALL_EXAMPLES = $(shell $(call list_examples))
TFLINT_CONFIG ?= .tflint.hcl
VAR_FILE ?= test.tfvars
AWS_PROFILE ?= default
AWS_REGION ?= us-east-2

# ------------------------------------------------------------------------------
# Functions — Golang
# ------------------------------------------------------------------------------

# Checks for Go files in the GO_TEST_DIRECTORIES. If they exist, runs the default configuration for golangci-lint
# https://golangci-lint.run/usage/quick-start/
define go_lint
	$(FIND) $(1)/ -name '*.go' | $(GREP) -q '\.go' || exit 0; $(GOLANGCI_LINT) run -c $(GOLANGCI_LINT_CONFIG) -v ./$(1)/...;

endef

# Check for Go files. If they exist, run tests. Either runs only readonly tests(default) or tests except readonly ones
define go_test
	$(FIND) $(1)/ -name '*.go' |$(GREP) $(2) $(GO_TEST_READONLY_DIRECTORY) | $(GREP) -q '\.go' || exit 0; $(GO) test -v -count=1 -timeout=$(GO_TEST_TIMEOUT) $$($(GO) list ./$(1)/...|$(GREP) $(2)  $(GO_TEST_READONLY_DIRECTORY)) ;

endef

# ------------------------------------------------------------------------------
# Functions — Terraform module
# ------------------------------------------------------------------------------

define check_terraform_fmt
	echo && echo "Formatting Terraform files ...";
	$(TERRAFORM) fmt -recursive;

endef

define clean_terraform_module
	$(RM) $(1)/.terraform* $(1)/terraform.*;
	$(RM) $(1)/provider.tf
endef

define init_terraform_module
	echo && echo "Initializing $(1) ...";
	$(TERRAFORM) -chdir=$(1) init -backend=false -input=false;

endef

define list_terraform_modules
	$(FIND) . -path "*/.terraform" -prune -o -name "main.tf" -not -path '*pipeline*' -not -path '*examples*' -exec dirname {} \;;

endef

define list_examples
	$(FIND) ./examples -path "*/.terraform" -prune -o -name "main.tf" -not -path '*pipeline*' -exec dirname {} \; 2>/dev/null
endef

# ------------------------------------------------------------------------------
# Provider templates
# ------------------------------------------------------------------------------
# When running `make lint` or `make test`, provider configuration files are
# auto-generated for each example directory based on the providers declared in
# `terraform providers` output.  The define blocks below contain the default
# content written to each example's provider.tf for the matching registry
# provider.
#
# To override auto-generation entirely, set the PROVIDER_TEMPLATE environment
# variable to the path of a custom provider.tf file:
#
#   $ PROVIDER_TEMPLATE=my-provider.tf make test
#
# When set, that file is copied verbatim into every example directory instead of
# running the per-provider detection logic below.
# ------------------------------------------------------------------------------

PROVIDER_TEMPLATE ?=

define aws_provider
provider \"aws\" {\n  region  = \"$(AWS_REGION)\"\n  profile = \"$(AWS_PROFILE)\"\n}\n\nprovider \"aws\" {\n  alias   = \"global\"\n  region  = \"us-east-1\"\n  profile = \"$(AWS_PROFILE)\"\n}\n
endef

define azurerm_provider
provider \"azurerm\" {\n  skip_provider_registration = true\n  features {\n    resource_group {\n      prevent_deletion_if_contains_resources = false\n    }\n  }\n}\n
endef

define azapi_provider
provider \"azapi\" {\n  use_cli = true\n  use_msi = false\n}\n
endef

define azuredevops_provider
provider \"azuredevops\" {}\n
endef

define provider_file_path
$(1)/provider.tf
endef

define add_provider_details
	$(if $(findstring hashicorp/aws,$(2)),grep -qs "aws" $(1) || bash -c 'echo -e "$(call aws_provider)"' >> $(1),)
	$(if $(findstring azure/azapi,$(2)),grep -qs "azapi" $(1) || bash -c 'echo -e "$(call azapi_provider)"' >> $(1),)
	$(if $(findstring microsoft/azuredevops,$(2)),grep -qs "azuredevops" $(1) || bash -c 'echo -e "$(call azuredevops_provider)"' >> $(1),)
	$(if $(findstring hashicorp/azurerm,$(2)),grep -qs "azurerm" $(1) || bash -c 'echo -e "$(call azurerm_provider)"' >> $(1),)
endef

define create_example_providers
	$(eval PROVIDER_FILE_PATH:=$(call provider_file_path,$(1)))
	$(foreach PROVIDER,$(shell terraform providers | sed -re 's/.+\[(.+\/.+\/.+)\].+/\1/g' | grep registry | sort | uniq),$(call add_provider_details,$(PROVIDER_FILE_PATH),$(PROVIDER)))
endef

define plan_terraform_module
	echo && echo "Planning $(1) ...";
	if [ -f "$(1)/$(VAR_FILE)" ]; then \
		echo "Using $(VAR_FILE) for variable inputs"; \
		$(TERRAFORM) -chdir=$(1) plan -input=false -out=terraform.tfplan -var-file $(VAR_FILE); \
	else \
		echo "$(VAR_FILE) doesn't exist, falling back to default (terraform.tfvars)"; \
		$(TERRAFORM) -chdir=$(1) plan -input=false -out=terraform.tfplan; \
	fi;
	echo && echo "Creating JSON plan output for $(1) ...";
	cd $(1) && $(TERRAFORM) show -json ./terraform.tfplan > ./terraform.tfplan.json;

endef

define tflint_terraform_module
	echo && echo "Linting $(1) ...";
	(cd $(1) && TF_LOG=info $(TFLINT) -c $(PWD)/$(TFLINT_CONFIG)) || exit 1;

endef

define validate_terraform_module
	echo && echo "Validating $(1) ...";
	$(TERRAFORM) -chdir=$(1) validate || exit 1;

endef

# ==============================================================================
# Targets — Setup / Configuration
# ==============================================================================

.PHONY: configure-dependencies
configure-dependencies:
ifeq ($(MISE_INSTALLED), 0)
	@echo "Installing dependencies using mise"
	@awk -F'[ #]' '$$NF ~ /https/ {system("mise plugin install " $$1 " " $$NF " --yes")} $$1 ~ /./ {system("mise install " $$1 " " $$2 " --yes")}' ./.tool-versions
else ifeq ($(ASDF_INSTALLED), 0)
	@echo "Installing dependencies using asdf-vm"
	@awk -F'[ #]' '$$NF ~ /https/ {system("asdf plugin add " $$1 " " $$NF)} $$1 ~ /./ {system("asdf plugin add " $$1 "; asdf install " $$1 " " $$2)}' ./.tool-versions
else
	$(error Missing supported dependency manager. Install asdf-vm (https://asdf-vm.com/) or mise (https://mise.jdx.dev/) and rerun)
endif

.PHONY: configure-git-hooks
configure-git-hooks: configure-dependencies
ifeq ($(PYTHON3_INSTALLED), 0)
	pre-commit install
else
	$(error Missing python3, which is required for pre-commit. Install python3 and rerun.)
endif

.PHONY: configure
configure: configure-git-hooks
ifneq ($(and $(GIT_USER_SET), $(GIT_EMAIL_SET)), 0)
	$(error Git identities are not set! Set your user.name and user.email using 'git config' and rerun)
endif

.PHONY: clean
clean:
	$(MAKE) tfmodule/clean

# ==============================================================================
# Targets — Check / Lint / Test (base double-colon rules)
# ==============================================================================

.PHONY: check
check:
	$(MAKE) lint
	$(MAKE) test

.PHONY: lint
lint::
	@true

.PHONY: test
test::
	@true

# ==============================================================================
# Targets — Golang
# ==============================================================================

.PHONY: go/test/environment/az
go/test/environment/az:
ifeq (,$(ARM_SUBSCRIPTION_ID))
	$(error "ARM_SUBSCRIPTION_ID was not set and `az` was not found in your PATH.")
else
	@echo "Terratest will use Azure Subscription ID $$ARM_SUBSCRIPTION_ID"
endif

.PHONY: go/test/environment/aws
go/test/environment/aws:
	@echo "No environment configuration for AWS is defined."

.PHONY: go/test/environment/gcp
go/test/environment/gcp:
	@echo "No environment configuration for GCP is defined."

# Performs any environmental setup required for a cloud provider based on the name of the repository.
.PHONY: go/test/environment
go/test/environment:
ifneq (,$(findstring tf-aws,$(CURRENT_DIR)))
	$(MAKE) go/test/environment/aws
else ifneq (,$(findstring tf-az,$(CURRENT_DIR)))
	$(MAKE) go/test/environment/az
else ifneq (,$(findstring tf-gcp,$(CURRENT_DIR)))
	$(MAKE) go/test/environment/gcp
else
	@echo "Unrecognized module type, no environmental setup will be performed."
endif

.PHONY: go/list
go/list:
	@echo -n "Test dirs: "
	@echo $(GO_TEST_DIRECTORIES) | tr ' ' '\n' | sort

.PHONY: go/lint
go/lint:
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_lint,$(test_dir)))

.PHONY: go/test
go/test: go/test/environment
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_test,$(test_dir),$(TEST_RUN_EXCLUDE_READONLY)))

.PHONY: go/readonly_test
go/readonly_test:
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_test,$(test_dir),$(TEST_RUN_ONLY_READONLY)))

# Golang extensions to lint / test
.PHONY: lint
lint::
ifeq ($(DISABLE_MAKE_CHECK_LINT),false)
	$(MAKE) go/lint
else
	$(info "make go/lint has been disabled!")
endif

.PHONY: test
test:: tfmodule/plan
	$(MAKE) go/test

# ==============================================================================
# Targets — Terraform module
# ==============================================================================

.PHONY: tfmodule/all
tfmodule/all: lint

.PHONY: tfmodule/clean
tfmodule/clean:
	@$(foreach module,$(ALL_TF_MODULES),$(call clean_terraform_module,$(module)))

.PHONY: tfmodule/fmt
tfmodule/fmt:
	$(TERRAFORM) fmt -recursive;

.PHONY: tfmodule/init
tfmodule/init:
	@$(foreach module,$(ALL_TF_MODULES),$(call init_terraform_module,$(module)))
	@$(foreach module,$(ALL_EXAMPLES),$(call init_terraform_module,$(module)))

.PHONY: tfmodule/lint
tfmodule/lint: tfmodule/init
	@$(call check_terraform_fmt)
	@$(foreach module,$(ALL_TF_MODULES),$(call tflint_terraform_module,$(module)))
	@$(foreach module,$(ALL_TF_MODULES),$(call validate_terraform_module,$(module)))
	@$(foreach module,$(ALL_EXAMPLES),$(call tflint_terraform_module,$(module)))
	@$(foreach module,$(ALL_EXAMPLES),$(call validate_terraform_module,$(module)))

.PHONY: tfmodule/list
tfmodule/list:
	@echo -n "Modules: "
	@echo $(ALL_TF_MODULES) | tr ' ' '\n' | sort
	@echo -n "Examples: "
	@echo $(ALL_EXAMPLES) | tr ' ' '\n' | sort

.PHONY: tfmodule/plan
tfmodule/plan: tfmodule/init
	@$(foreach module,$(ALL_EXAMPLES),$(call plan_terraform_module,$(module)))

.PHONY: tfmodule/create_example_providers
tfmodule/create_example_providers: tfmodule/init
ifdef PROVIDER_TEMPLATE
	@$(if $(wildcard $(PROVIDER_TEMPLATE)),,$(error PROVIDER_TEMPLATE is set to '$(PROVIDER_TEMPLATE)' but the file does not exist))
	@$(foreach example,$(ALL_EXAMPLES),cp $(PROVIDER_TEMPLATE) $(call provider_file_path,$(example));)
else
	@$(if $(findstring aws.global,$(shell grep -se "\\s*provider\\s*=" *.tf || true)),$(call create_example_providers,.),)
	@$(foreach example,$(ALL_EXAMPLES),$(call create_example_providers,$(example)))
endif

# Terraform module extensions to lint / test
.PHONY: lint
lint::
	$(MAKE) tfmodule/create_example_providers
	$(MAKE) tfmodule/lint

.PHONY: test
test::
	$(MAKE) tfmodule/create_example_providers
	$(MAKE) tfmodule/plan
