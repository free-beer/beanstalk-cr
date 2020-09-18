# beanstalk-cr

A Crystal library for interfacing with the Beanstalk queue.

[![GitHub release](https://img.shields.io/github/release/free-beer/beanstalk-cr.svg)](https://github.com/free-beer/beanstalk-cr/releases)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     beanstalk-cr:
       github: https://github.com/free-beer/beanstalk-cr.git
   ```

2. Run `shards install`

## Usage

```crystal
require "beanstalk-cr"
```

All code for the library is contained within a module called ```Beanstalk```.
To connect to a Beanstalk server instance you can call the ```open()``` method
on the ```Beanstalk::Connection``` class like this...

```crystal
  connection = Beanstalk::Connection.open()
```

This will attempt to connect to a server running on ```localhost``` at the
default Beanstalk port number (11300). If you want to change the server that
gets connected to you can specify that in the call to ```open()``` like
this...

```crystal
  connection = Beanstalk::Connection.open("my.host.name", 12345)
```

Once you have a connection to a Beanstalk instance you can use it to obtain a
```Tube``` instance. Tubes are used by Beanstalk as a primary interaction
interface. There are two primary mechanisms for obtaining a ```Tube``` from a
```Connection``` and these are shown below...

```crystal
  tube1 = connection.default_tube
  tube2 = connection["my_q"]
```

The differences between these requires an explanation of the Beanstalk concepts
of 'using' and 'watching'. These concepts refer to actual queues on the Beanstalk
server and how your ```Tube``` instance interacts with them. The queue that a
```Tube``` is using will be the queue that it inserts content into. A ```Tube```
can only be 'using' a single queue. On the other hand, a ```Tube``` can be
`watching` multiple queues and these are the queues that the ```Tube``` will
check when it's looking to receive content.

In the code above, using ```connection.default_tube``` will retrieve a ```Tube```
instance that is using and watching only the default queues (i.e. the queue
with the name 'default'). Using ```connection["my_q"]``` will retrieve a
```Tube``` that is using and watching a queue called "my_q". Note, that if a
queue does not exist when you request to use or watch it, Beanstalk will
automatically create it.

The queues that a ```Tube``` instance is using or watching can be changed after
the ```Tube``` instance has been obtained using calls like...

```crystal
  tube.use "other_q"
  tube.watch "a_third_q"
```

### Jobs

Beanstalk refers to the content of it's queues as jobs. In general terms a job
is a collection of data that has been inserted into a queue or can be retrieved
from a queue. This is modelled in the library with the ```Job``` class. To create
a new ```Job``` you can simply construct it. Once constructed you can add data to
the ```Job``` instance. The code below shows some examples of this...

```crystal
  # Create an empty job.
  job1 = Beanstalk::Job.new

  # Create a job populated with data from a String.
  job2 = Beanstalk::Job.new("The data content for the job.")

  # Create a job from an Array(UInt8).
  array = [1_u8, 2_u8, 3_u8, 4_u8, 5_u8]
  job3  = new Beanstalk::Job(array)

  # Create a job from a Slice(UInt8)
  slice = Slice.new(array.to_unsafe, array.size)
  job4  = new Beanstalk::Job(slice)

  # Create a job from mixed data sources.
  job5 = new Beanstalk::Job("Some text.", array, slice)
```

Data can be added to an existing ```Job``` instance by calling one of it's
```append()``` methods. You can check the size of a ```Job``` (i.e. the number of
bytes of data it contains) by calling the ```size()``` method and fetch the actual
data by calling the ```bytes()``` method. A call to the ```to_s()``` method will
attempt to convert the ```Job``` data to a ```String``` so don't call this unless
you're sure that data actually does represent a ```String```.

Once you have a ```Job``` you can add it to a Beanstalk queue by calling the
```put()``` method on a ```Tube``` instance. The ```Job``` will be added to the
queue that the ```Tube``` is currently set to use. Prior to being added to a
queue a ```Job``` instance will have a ```nil``` value for it's ```id```
attribute. After being added the ```id``` will be updated to match the id value
assigned to the ```Job``` by Beanstalk. Examples of adding jobs to a Beanstalk
queue are shown below...

```crystal
  tube = Beanstalk::Connection.open.default_tube

  # Adding a job with default settings for priority, delay and TTR.
  job1 = Beanstalk::Job.new("Some content for my first job.")
  tube.put(job1)

  # Adding a job with explicit settings for priority, delay and TTR.
  settings = Beanstalk::JobSettings.new(0, 120, 600)
  job2     = Beanstalk::Job.new("Some different content for my second job.")
  tube.put(job2, settings)
```

When adding a ```Job``` to a queue Beanstalk has three associated concepts called
priority, delay and time to run (TTR). Priority is a mechanism saying something
about the relative importance of different jobs, with lower priority settings being
considered more important and therefore getting delivered sooner. A jobs delay
setting indicates to Beanstalk that it should hold off on making the job available
for retrieval for a specific number of seconds. Finally a jobs TTR indicates how
much time a client has (in seconds) to do something with a job before Beanstalk will
release their hold on the job and make it available for retrieval again.

Another way to obtain a ```Job``` instance is to retrieve one from the Beanstalk
server. The primary mechanism for doing this is referred to by Beanstalk as
'reserving' the job. When you reserve a job from Beanstalk you are taking
temporary ownership of the job. At some future point it is expected that you
will either delete the job, release ownership of it or 'bury' it. The TTR setting
for a job when it is created indicates how long (in seconds) you have to act on
a job before the Beanstalk server will return it to the population of jobs that
are available to be reserved. Examples of fetching jobs from Beanstalk are shown
below...

```crystal
  # Returns immediately with either a Job instance or nil.
  job1 = tube.reserve?

  # Waits a most the specified time span for a job to become available or
  # returns nil if the time expires and a job is not available.
  job2 = tube.reserve(Time::Span.new(seconds: 10))

  # Block until a job becomes available.
  job3 = tube.reserve
```

Once you have a ```Job``` instance you can perform whatever associating processing
that you want. Once this is finished you must do something to indicate to the
Beanstalk server that you are finished with the ```Job```. To do any of these things
you must have already have reserved the ```Job``` and the TTR for the ```Job``` must
not have expired. Examples of what you can do include...

```crystal
  # Delete the job from the Beanstalk queue.
  tube.delete(job)

  # Release the job back to Beanstalk so that it can be reserved again.
  tube.release(job)

  # Release the job giving it different priority and delay settings.
  settings = Beanstalk::JobSettings.new(250, 600)
  tube.release(job, settings)

  # Touch the job, resetting the TTR for your reservation.
  tube.touch(job)

  # Bury the job (i.e. make it unavailable for reservation until it is 'kicked' back
  # into the ready pool).
  tube.bury(job)
```

This covers the primary usage for the library. There are other capabilities provided
by the library but you should consult the API documentation for further details.

### Environment Settings

The library takes note of a number of enviroment settings that can alter how it operates
when these are set. These are detailed below...

**BEANSTALK_CONNECT_TIMEOUT** - Is used to set the time out on obtaining an initial
connection to a Beanstalk server. Defaults to 10 seconds and should be an integer value.

**BEANSTALK_DEFAULT_JOB_DELAY** - Is used to set the default delay assigned to jobs added
to Beanstalk without an explicit delay. Default to zero and should be an integer value.

**BEANSTALK_DEFAULT_JOB_PRIORITY** - Is used to set the default priority assigned to jobs
added to Beanstalk without an explicit priority. Defaults to 1000 and should be an integer
value.

**BEANSTALK_DEFAULT_JOB_TTR** - Is used to set the default time to run assigned to jobs
added to Beanstsalk without an explicit TTR. Defaults to 3600 (1 hour) and should be an
integer value (in seconds).

**BEANSTALK_READ_BUFFER_SIZE** - Is used to set the buffer sized for reading Beanstalk
messages from the server. Might be useful to bump in size if you're using very large
jobs but probably not. Should be an integer value.

## Development

Code is freely available, so familiarize yourself with that. Note that the unit tests
require an actual instance of Beanstalk to run and assume that they will be using an
instance on localhost at the default port number.

## Contributing

1. Fork it (<https://github.com/your-github-user/beanstalk-cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

Pull requests will be reviewed as soon as is possible, though no timeline is
guaranteed. Ultimate decision on whether a PR gets merged or not remains my
perogative.

## Contributors

- [Peter Wood](https://github.com/free-beer) - creator and maintainer
