# AJ

Aj is a simple command line tool for accessing json based apis. It is specificially useful for testing because you can save the parameters to a file so you can easily make the same API call multiple times while slightly tweaking the parameters. This is meant to be a more convenient way to test an API call than using `curl` or filling out a browser based form.


## Installation

For now, clone this github repository and add the `aj` script to your path. You also need to have Ruby 1.9+ and have the `hashie` gem installed.

To test your install, run:

```
aj --help
```

Hopefully this project will be turned into a gem in the future to make installation easier.


## Running

To run aj, use the terminal app and run `aj` at the command line. Usually you will specify a file that contains the necessary parameters to make the call (the file format is specified below in the Configuration section). Aj will make the specified API call with the specified the parameters, and then try to parse the result as JSON and output the result in a readable format.

The typical command would look like this:

```bash
aj -f config.yml
```

And the output of a typical command might look like this:

```json
{
  "result": "success"
  "message": "The operation was successful"
}
```


## Examples

Load parameters from a configuration file:

```bash
aj -f file.yml
```

Specify parameters via command line:

```bash
aj --host http://example.com --token <token-goes-here> --location users/1/name --http-method put --arg name=myself --arg age=42
```

To print the raw result instead of trying to parse it as json:

```bash
aj -f config.yml --raw
```

To view the final merged configuration without running the command:

```bash
aj -f config.yml --dump-config
```

## Configuration

Aj reads it's configuration from three sources:

 * ~/.ajconfig
 * The file(s) specified by the `-f` command line parameter
 * Other command line parameters

Options specified in sources lower in the list override the options specified from sources higher in the list. So, for example, you can always override an option with a command line parameter. Some parameters (`args`, `headers`) are merged from all sources instead of being overwritten.

The files are formatted in [YAML][yaml] and generally accept the same options as specified by the `aj --help` command. Where the command line uses dashes, **the config files use underscores instead**. So while on the command line you would specify `--http-method get`, in a config file you would specify `http_method: get`

[yaml]: http://yaml.org/

The `arg` parameter is special. In the configuration file, it becomes `args` and its value is a hash of key-value pairs. The `arg` parameters from all sources are merged into a single, final arguments hash. If a key is specified in multiple sources, the values are merged into an array of values.

The `header` parameter behaves similary to `arg`, appearing as `headers` in the configuration file.

The `tokens` parameter is not available on the command line and is specific to file configurations. The value of the `tokens` parameter is a hash of user names to token values. These user names can then be referred to using the `--user` parameter, making it easy to save and reference a token later.

If you're unsure about how a specific aj command will be configured, use the `--dump-config` option to make aj dump its configuration and exit without running the command.

Here is an example ~/.ajconfig file:

```yaml
host: localhost
port: 3000
api_prefix: api/v1
tokens:
  student: <the-student-token-goes-here>
  teacher: <the-teacher-token-goes-here>
```

Here is an example of a normal configuration file:

```yaml
location: users/1
http_method: put
args:
  name: myself
  age: 42
```

And you might call it like this:

```bash
aj -f normal.yml --user student --dump-config
```

Which would output the resulting configuration:

```yaml
---
port: 3000
api_prefix: api/v1
http_method: put
headers: {}
host: localhost
tokens:
  student: <the-student-token-goes-here>
  teacher: <the-teacher-token-goes-here>
location: users/1
args:
  name:
  - myself
  age:
  - 42
user: student
dump_config: true
```

## Contributing

Make a suggestion, file an issue, correct my spelling, send words of encouragement, fork the repository and implement a feature you need, make a pull request... You know, all the standard GitHub stuff.

## To Do

 * Make the default api-prefix less specific to Canvas
 * Split the single file script into multiple files and classes.
    * This is to prepare to make it a gem.
 * Turn it into a gem for easy installation.
 * Create unit tests
 * Remove dependency on `hashie`.
 * Add more authentication schemes than just `Bearer <token>`.
