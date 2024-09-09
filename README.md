# GitHub Actions for Yandex Cloud Load Testig service

## Summary

List of available actions:
* agents-create - create and start load testing agents using Yandex Cloud Compute VMs for hosting (Compute is billed separately)
* agents-delete - delete load testing agents
* test-suite - execute multiple load tests sequentially
* test-single-run - execute a single load test
* test-single-check - check results of a single load test

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
  action-log-level: NOTICE

  # (Optional) Same as auth-key-json-base64, but expects an unencoded value.
  # The use of this parameter is discouraged because it can lead to unwanted
  # logs obfuscation (see https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#naming-your-secrets).
  #
  # Ignored, if auth-key-json-base64 is set.
  auth-key-json: ${{ secrets.YC_KEY }}
```

### agents-create

```
uses: yandex-cloud/yc-github-loadtesting-ci/agents-create@main
with:
  # See 'common configuration'.
  folder-id: ${{ vars.YC_FOLDER_ID }}
  auth-key-json-base64: ${{ secrets.YC_KEY_BASE64 }}

  # (Optional) Time (in seconds) to wait until created agents become ready for tests execution. Default is 600.
  #
  # The most likely reason of reaching this timeout is invalid agent configuration (no public IP or NAT, strict security group, etc.)
  timeout: 600

  # (Optional) Number of agents to create. Default is 1.
  count: 1

  # (Optional) Arguments to be passed to YC CLI. Default is an empty string.
  # If --network-interface is not provided, created agent will have a one-to-one NAT (dynamic public IP) in an automatically chosen subnet.
  #
  # YC CLI command: `yc loadtesting agent create ARGS`.
  cli-args: ''

  # (Required if --service-account-id is missing in cli-args) ID of a service account to run an agent VM on.
  #
  # --service-account-id option in cli-args overrides this parameter.
  service-account-id: ${{ vars.YC_LOADTESTING_AGENT_IC }}

  # (Optional) Compute zone to create agent VM in. Default is 'ru-central1-d'.
  #
  # --zone option in cli-args overrides this parameter.
  vm-zone: ru-central1-d

  # (Optional) Agent name prefix (full name, if count=1). Default is 'onetime-ci-agent'.
  #
  # --name option in cli-args overrides this parameter.
  name-prefix: github-actions-agent

  # (Optional) Agent description.
  #
  # --description option in cli-args overrides this parameter.
  description: ''

  # (Optional) Agent labels in 'key1=value1,key2=value2' format.
  #
  # --labels option in cli-args overrides this parameter.
  labels: 'souce=github'
```

### agents-delete

todo

### test-sute

todo

### test-single-run

todo

### test-single-check

todo


