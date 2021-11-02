# Hardware testing scripts

## mender configure update module script

Location of `hw-test-deploy-image.sh` is: *testfarmpi4master*:`/usr/lib/mender-configure/apply-device-config.d/hw-test-deploy-image.sh`
it is the Mender Configure script to handle the image deployments. It accepts one parameter: `"image"`, which is either an URL to the image
to be deployed, or `-` to reset the device configuration (to be able to deploy the same image again).

Please note:
* it removes existing image
* it removes image after successful deployment

## deploy_configuration.sh

For use in CI/CD pipelines (maybe only the internals, to be decided), to trigger the configuration change on the device. The call sequence 
is exactly the same as when you save configuration from the UI.

Accepts two parameters:
* `deviceid` -- the id of a device
* `image` -- and URL or `-` as the image passed to the configure (see above)

Expects `AUTH_TOKEN` environment variable to be not empty, and uses its value as JWT for in all the API calls.
Allows to override the default `hosted.mender.io` server URL with `SERVER_URL` environment variable.

