require('dotenv').config();
const amqp_url = process.env.RABBITMQ_URL || 'amqp://localhost';
const queue = process.env.RABBITMQ_QUEUE || 'default';
const amqp = require('amqplib/callback_api');

amqp.connect(amqp_url, (error, connection) => {
  if (error) { throw error; }

  connection.createChannel((err, channel) => {
    if (err) { throw err; }
    const msg = 'Hello World!';

    channel.assertQueue(queue, {
      durable: true
    });

    channel.sendToQueue(queue, Buffer.from(msg));
    console.log(" [x] Sent %s", msg);
  });

  setTimeout(() => {
    connection.close();
    process.exit(0);
  }, 500);
});