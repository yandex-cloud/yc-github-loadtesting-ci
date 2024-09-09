# GitHub Actions for Yandex Cloud Load Testig service

## Summary

List of available actions:
* _agents-create_ - create and start load testing agents using Yandex Cloud Compute VMs for hosting (Compute is billed separately)
* _agents-delete_ - delete load testing agents
* _test-suite_ - execute multiple load tests sequentially
* _test-single-run_ - execute a single load test
* _test-single-check_ - check results of a single load test

## Configuration

Common:
```yaml
with:
  # (Required) ID of a folder in Yandex Cloud.
  # An action is performed on behalf of a service account created in this folder
  # using authentication via 'Authorized Key' (see 'auth-key-json-base64' argument)
  folder-id: ${{ vars.YC_FOLDER_ID }}

  # (Required) Action authentication in Yandex Cloud.
  # Base64 encoded value of an authorized key json string.
  # Given a downloaded authorized_key.json file, just call `base64 <authorized_key.json >authorized_key.pem`
  # in the command line and copy the content of result authorized_key.pem file to some GitHub Action secret.
  # 
  # A service account, for which this authorized key was generated,
  # must be allowed to perform all subject action operations it is asked to.
  # Operations:
  #   - create a load testing agent
  #   - create a compute VM
  #   - create a load test
  #   - etc.
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}

  # (Optional) Action logs verbosity level.
  # One of: NOTICE, INFO, DEBUG (default=NOTICE)
  # action-log-level: NOTICE
```

### agents-create

Create agents alongside with Cloud Compute VMs to host them.
  
This action is usually used used in pair with 'agents-delete' action.

SA authorized by `auth-key-json-base64` must have following roles in `folder-id`:
- `loadtesting.loadTester` - to create an agent
- `compute.editor` - to create and start agent VM
- `iam.serviceAccounts.user` - to assign service account to agent VM
- `vpc.user` - to configure network interface on agent VM
- `vpc.publicAdmin` - to configure public IP on agent VM (the default way, may be omitted if you know what you are doing)

For full specification, see [agents-create/action.yml](agents-create/action.yml).

#### **With defaults**
- **Resources**: 2 CPU, 2 GB RAM (default)
- **Network**: one-to-one NAT (dynamic public IP) in automatically selected subnet (default)

```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
with:
  # See 'common configuration'.
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}

  # Agent service account ID (with role 'loadtesting.generatorClient').
  service-account-id: ${{ vars.YC_LOADTESTING_SA_ID }}

  # Agent labels.
  labels: "workflow=${{ github.run_id }}"

  # Number of agents to be created.
  # count: 1

  # Compute zone to run agent VM in.
  # vm-zone: ru-central1-a
```

#### **With manually specified VM configuration**
- **Resources**: CPU and RAM settings are passed via `cli-args`
- **Network**: one-to-one NAT (dynamic public IP) in automatically selected subnet (default)

<details><summary>YAML configuration...</summary>

```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
with:
  # See 'common configuration'.
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}

  # Agent service account ID (with role 'loadtesting.generatorClient').
  service-account-id: ${{ vars.YC_LOADTESTING_SA_ID }}

  # Agent labels.
  labels: "workflow=${{ github.run_id }}"

  # Number of agents to be created.
  # count: 1

  # Compute zone to run agent VM in.
  # vm-zone: ru-central1-a

  # Additional cli arguments.
  cli-args: |-
    --cores 2
    --memory 2G
```

</details>

#### **With manually specified network settings**
- **Resources**: passed via `cli-args`
- **Network**: passed via `cli-args`

This version is essentially identical to `yc loadtesting agent create ${cli-args}`.

<details><summary>YAML Configuration...</summary>

```yaml
uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
with:
  # See 'common configuration'.
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}

  # Number of agents to be created.
  # count: 1

  # Additional cli arguments.
  cli-args: |-
    --service-account-id "${{ vars.YC_LOADTESTING_SA_ID }}"
    --labels "workflow=${{ github.run_id }}"
    --cores 2
    --memory 2G
    --zone 'ru-central1-a'
    --network-settings "subnet-name=default-a,security-group-ids=${{ vars.YC_LOADTESTING_AGENT_SECURITY_GROUP_ID }}"
```

</details>

### agents-delete

todo

### test-sute

todo

### test-single-run

todo

### test-single-check

todo


