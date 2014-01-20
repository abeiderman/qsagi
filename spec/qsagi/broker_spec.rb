require "spec_helper"

describe Qsagi::Broker do
  subject(:broker) { Qsagi::Broker.new }

  describe "#connect" do
    context "with default config" do
      before { broker.connect }

      its(:connection) { should be_a Bunny::Session }
      its(:channel) { should be_a Bunny::Channel }
      its(:exchange) { should be_a Bunny::Exchange }
    end

    context "with invalid config" do
      subject(:broker) { Qsagi::Broker.new(host: "invalid") }
      let(:connect) { -> { broker.connect } }

      specify { connect.should raise_error }
    end
  end

  describe "#disconnect" do
    it "disconnects and clears ivars" do
      broker = Qsagi::Broker.new
      broker.connect
      broker.disconnect

      broker.connection.should be_nil
      broker.channel.should be_nil
      broker.exchange.should be_nil
    end
  end

  describe "#publish" do
    context "with connection" do
      before { broker.connect }
      after { broker.disconnect }

      it "publishes a message to an exchange" do
        broker.exchange.should_receive(:publish).once
        broker.publish("qsagi.key", "message")
      end

      it "dumps the message as JSON" do
        broker.exchange.should_receive(:publish).with("{}", anything).once
        broker.publish("qsagi.key", {})
      end

      it "adds time and ID meta-data to message" do
        SecureRandom.stub(:uuid).and_return("abcdef")

        metadata = {
          routing_key: "qsagi.key",
          timestamp: Time.now.to_i,
          message_id: "abcdef",
          content_type: "application/json"
        }

        broker.exchange.should_receive(:publish).with("{}", metadata).once
        broker.publish("qsagi.key", {})
      end
    end

    context "without connection" do
      it "raises an error" do
        expect do
          broker.publish("qsagi.key", "message")
        end.to raise_error(Qsagi::PublishError)
      end
    end
  end

  describe "#queue" do
    before { broker.connect }
    after { broker.disconnect }
    let(:queue) { broker.queue("qsagi.test") }

    it "returns a named queue" do
      queue.name.should == "qsagi.test"
    end

    it "returns a durable queue" do
      queue.should be_a Bunny::Queue
      queue.should be_durable
    end
  end

  describe "#bind_queue" do
    subject(:broker) { Qsagi::Broker.new(exchange: "qs") }
    before { broker.connect }
    after { broker.disconnect }
    let(:queue) { broker.queue("qsagi.test") }

    it "binds to exchange with given routing keys" do
      routing_keys = %w[test1 test2]
      queue.should_receive(:bind).with(anything, routing_key: "test1").once
      queue.should_receive(:bind).with(anything, routing_key: "test2").once
      broker.bind_queue(queue, routing_keys)
    end
  end
end
