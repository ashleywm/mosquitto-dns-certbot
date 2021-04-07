# mosquitto-dns-cerbot

An a docker image that integrates the [Mosquitto MQTT server](https://mosquitto.org/) with [Certbot](https://certbot.eff.org/) using [Cloudflare DNS challenges](https://certbot-dns-cloudflare.readthedocs.io/en/stable/) for automatic generation and renewal of [Letsencrypt](https://letsencrypt.org/) certificates.

As the Internet of Things (IoT) world rapidly grows and evolves, developers need a simple and secure way to implement peer-to-peer and peer-to-server (backend) communications. MQTT is a relatively simple message/queue-based protocol that provides exactly that.
Unfortunately, there are a ton of Docker images available for MQTT brokers, e.g. eclipse-mosquitto; but, nearly all of them leave it up to the user to figure out how to secure the platform. This results in many developers simply ignoring security altogether for the sake of simplicity. Even more dangerous, many semi-technical home owners are now dabbling in the home automation space and due to the complexity of securing system, they are hanging IoT/automation devices on the internet completely unsecurred.

This docker image attempts to make it easier to implement a secure MQTT broker, either in the cloud or on premise. The secured broker can be used with home automation platforms like [Home Assistant](https://home-assistant.io/) or simply as a means of enabling secure IoT device communications.

## Environment Variables

There are three environment variables useable with this image. DOMAIN and EMAIL are required for Certbot/Letsencrypt to obtain certificates necessary for secure communications. The third, DRYRUN, is optional.

**DOMAIN** - This should be defined as your fully qualified domain name, i.e. mqtt.myserver.com. The domain needs to point to your server as LetsEncrypt will verify such when obtaining certificates.

**EMAIL** - This simply needs to be an email address. It's required by Certbot/LetsEncrypt to obtain certificates.

**DRYRUN** - This variable can be set to any value (e.g. TRUE). When defined, the image will utilize Certbot/LetsEncrypt --staging server and obtain non-valid test-certs. It will also use --dry-run when simulating certificate renewal.

## Volumes

The scripts associated with this image assume a standard directory structure for mosquitto configuration and Certbot/LetsEncrypt.

```
/mosquitto/conf/
	mosquitto.conf
	passwd
/mosquitto/log/
/letsencrypt/
/secrets/
```

**/mosquitto/conf/** - this directory is where Mosquitto will look for the mosquitto.conf file.

**/mosquitto/conf/mosquitto.conf** - this file is user supplied. The startup scripts will look for exactly this file in exactly this directory. If it isn't found, the container will exit with appropriate error messages.

**/mosquitto/conf/passwd** - this file is the standard location for Mosquitto users/passwords. An alternate file/location can be specified in mosquitto.conf, but it must be in a location persisted through docker volume mapping. It's presence/use is optional, but allowing anonymous access to MQTT somewhat defeats the purpose of this image.

**/mosquitto/log** - This directory is the location where mosquitto will place log file(s). Like passwd defined above, its use is optional and can be controlled based on the contents of mosquitto.conf.

**/letsencrypt** - This directory is where certbot/LetsEncrypt will place retrieved certificates. The certbot scripts specifically require/expect this directory to exist in the container, so it should be mapped.

**/scripts** - To enable customization of the container, the run.sh script looks for this directory. If it finds `/scripts`, it will look inside the directory for any file ending in .sh, e.g. myscript.sh. It will then attempt to execuite said script(s) during container startup, immediately after dealing with certbot/LetsEncrypt, but before starting Mosquitto. Scripts found will be executed in alpha order. A suggested naming convention for scripts include a number followed by a dash, then the script name, ending in .sh, e.g. 00-myfirstscript.sh, 01-mysecondscript.sh, etc. This will ensure your scripts are executed in the order intended. An example of this functionality would be if you want additional software/utilities in the container. The `sample/docker-compose.yml` file shows a local directory `./scripts` mapped to the container volume `/scripts` where `run.sh` will look for the above discussed user scripts to run at startup.

**/secrets** - This directory should contain your `cloudflare.ini` which contains the required cloudflare API token for certbot to use when performing a DNS challenge. A sample of this file and it's contents can be found [/sample/cloudflare.ini](/sample/cloudflare.ini)

## Certbot/LetsEncrypt Integration

At container startup, scripts will look to see if certificates for `DOMAIN` exist in `/letsencrypt`. If it doesn't find any certificates, it will attempt to obtain them.
If certificates do exist, then an attempt will be made to renew them (via certbot renew).
Once a week, scripts will be run to check to see if the certificates need renewal. If so, they will be renewed, then the mosquitto server will be restarted so that it picks up the new certificates. Unfortunately, this does mean that there will be a brief (few second) outage each time certificates are in fact renewed. Adjust use cases for this server accordingly.

## mosquitto.conf

Documentation for Mosquitto should be consulted for details on how to properly configure this file. However, a sample configuration file is provied in [/sample/mosquitto.conf](/sample/mosquitto.conf).

In the sample file, we make mosquitto available via three different ports. Port 1883 uses the standard mqtt protocol. It is accessible without TLS/SSL, but does require user id/password verification (defined in /mosquitto/conf/passwd). The use case for 1883 is that it is expose internally to other processes/servers on a private network. Port 8883 provides accessiblity via the mqtt protocol, but requires TLS/SSL. The use case is that port 8883 is exposed to the internet, accessible via DOMAIN. And lastly, port 8083 allows the server to be accessed via websockets. It also requires TLS/SSL. Again it's use case would be that port 8083 is exposed to the internet, accessible via DOMAIN.

Logging is enabled and the directory for storing log files is defined as /mosquitto/log. The highest level of detail for logging is enabled. Consult [Mosquitto documentation](https://mosquitto.org/documentation/) for the logging parameters if you want a lesser level of logging turned on once you have the server debugged and integrated with your other devices/software.

Anonymous access to the server is disabled, indicating all connections must be validated via user id/password.

## Generating User ID/Password

Mosquitto provides a utility (mosquitto_passwd) for adding users to a password file with encrypted passwords. Assuming the passwd file is in the standard location as shown in the mosquitto.conf file above, you can add a user/password combination to the file once the docker container is up and running, using the following command:

docker exec -it mqtt mosquitto_passwd -b /mosquitto/conf/passwd a_user pwd123

This command doesn't provide any feedback if successful, but does show errors if there are problems. You can verify success simply looking in the passwd file. You should see an entry similar to: `a_user:$6$+NKkI0p3oZmSukn9$mOUEEHUizK2zqc8Hk2l0JlHHXTW8GPzSonP9Ujrjhs1tVNQqN3lGCAFcFKnpJefOjUPwjqE5mZ qSjBl6BCKnPA==`

## Testing Your Server

To test your server locally (i.e. within the container), you can pop into the container and use mosquitto_pub and mosquitto_sub. Note that you'll need to do this from two separate terminal sessions so see the effect. If you receive error messages, look in the mosquitto error log (/mosquitto/log) for diagnostic information. You should also make sure the container came up properly using a command like:

```

docker logs mqtt

```

For the MQTT subscriber:

```

docker exec -it mqtt /bin/bash
mosquitto_sub -h <yourserveraddr> -u "a_user" -P "pwd123" -t "testQueue"

```

The mosquitto*sub command will block waiting for messages from \_testQueue*.

To publish a message to ++testQueue++, open another terminal and use the following:

```

docker exec -it mqtt /bin/bash
mosquitto_pub -h <yourserveraddr> -u "a_user" -P "pwd123" -t "testQueue" -m "Hello subscribers to testQueue!"

```

In the first (subscriber) terminal window, you should immediately see the message "Hello subscribers to testQueue!".
