require('dotenv').config();
const amqp_url = process.env.RABBITMQ_URL || 'amqp://localhost';
const queue = process.env.RABBITMQ_QUEUE || 'default';
const amqp = require('amqplib/callback_api');

amqp.connect(amqp_url, (error, connection) => {
  if (error) { throw error; }

  connection.createChannel((err, channel) => {
    if (err) { throw err; }
    channel.assertQueue(queue, {
      durable: true
    });

    console.log(" [*] Waiting for messages in %s. To exit press CTRL+C", queue);
    channel.consume(queue, (msg) => {
      console.log(" [x] Received %s", msg.content.toString());
    }, {
        noAck: true
      });
  });

});
