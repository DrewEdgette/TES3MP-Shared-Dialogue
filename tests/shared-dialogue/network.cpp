// Headless clients exercise the real server dispatcher and session authority.
// Run only against the isolated fixture server started by test-network.ps1.
#include <components/openmw-mp/Packets/Player/PacketPlayerDialogue.hpp>
#include <components/openmw-mp/NetworkMessages.hpp>
#include <components/openmw-mp/Version.hpp>
#include <RakPeerInterface.h>
#include <chrono>
#include <thread>
#include <iostream>
#include <stdexcept>

using namespace mwmp;
using namespace mwmp::dialogue;
using Clock = std::chrono::steady_clock;
int checks = 0;
#define CHECK(value) do { ++checks; if (!(value)) throw std::runtime_error("Failed: " #value); } while (false)

struct Client
{
    RakNet::RakPeerInterface* peer = RakNet::RakPeerInterface::GetInstance();
    RakNet::SystemAddress server;
    std::vector<Message> inbox;
    bool ready = false, accepted = false;
    std::string name;
    Client(const std::string& value) : name(value)
    {
        RakNet::SocketDescriptor socket(0, "127.0.0.1");
        CHECK(peer->Startup(1, &socket, 1) == RakNet::CRABNET_STARTED);
    }
    ~Client() { peer->Shutdown(100); RakNet::RakPeerInterface::DestroyInstance(peer); }
    void transmit(RakNet::BitStream& stream, int channel = CHANNEL_PLAYER)
    { peer->Send(&stream, HIGH_PRIORITY, RELIABLE_ORDERED, channel, server, false); }
    void header(RakNet::BitStream& stream, unsigned char id)
    { stream.Write(id); stream.Write(peer->GetMyGUID()); }
    void pump()
    {
        for (auto* packet = peer->Receive(); packet; peer->DeallocatePacket(packet), packet = peer->Receive())
        {
            if (packet->data[0] == ID_CONNECTION_REQUEST_ACCEPTED)
            {
                server = packet->systemAddress;
                accepted = true;
                RakNet::BitStream out;
                header(out, ID_GAME_PREINIT);
                out.Write(std::uint32_t(1));
                struct Sizes { std::uint32_t hashes, name; } sizes {1, 8};
                out.Write(sizes);
                out.Write(RakNet::RakString("test.esm"));
                out.Write(std::uint32_t(1));
                transmit(out, CHANNEL_SYSTEM);
            }
            else if (packet->data[0] == ID_SYSTEM_HANDSHAKE)
            {
                RakNet::BitStream out;
                header(out, ID_SYSTEM_HANDSHAKE);
                RakNet::RakString::SerializeCompressed(name.c_str(), &out);
                RakNet::RakString::SerializeCompressed(TES3MP_DEFAULT_PASSW, &out);
                transmit(out, CHANNEL_SYSTEM);
                RakNet::BitStream loaded;
                header(loaded, ID_LOADED);
                transmit(loaded, CHANNEL_SYSTEM);
            }
            else if (packet->data[0] == ID_PLAYER_BASEINFO) ready = true;
            else if (packet->data[0] == ID_PLAYER_DIALOGUE)
            {
                RakNet::BitStream in(packet->data, packet->length, false);
                in.IgnoreBytes(BasePacket::headerSize());
                PacketPlayerDialogue reader(nullptr);
                Message message;
                reader.serialize(&in, false, message);
                CHECK(reader.isPacketValid());
                inbox.push_back(message);
            }
        }
    }
    void connect(const std::string& hash)
    {
        std::string password = std::string(TES3MP_VERSION) + std::to_string(TES3MP_PROTO_VERSION) + hash;
        CHECK(peer->Connect("127.0.0.1", 25576, password.c_str(), static_cast<int>(password.size())) == RakNet::CONNECTION_ATTEMPT_STARTED);
        auto deadline = Clock::now() + std::chrono::seconds(5);
        while (!ready && Clock::now() < deadline) { pump(); std::this_thread::sleep_for(std::chrono::milliseconds(5)); }
        CHECK(accepted && ready);
    }
    void send(Message message)
    {
        RakNet::BitStream out;
        PacketPlayerDialogue writer(nullptr);
        writer.setGUID(peer->GetMyGUID());
        writer.serialize(&out, true, message);
        CHECK(writer.isPacketValid());
        transmit(out);
    }
    void changeCell(const char* command)
    {
        RakNet::BitStream out;
        header(out, ID_CHAT_MESSAGE);
        out.Write(RakNet::RakString(command));
        transmit(out);
    }
    Message wait(Action action, std::uint64_t request = 0)
    {
        auto deadline = Clock::now() + std::chrono::seconds(5);
        while (Clock::now() < deadline)
        {
            pump();
            for (auto it = inbox.begin(); it != inbox.end(); ++it)
                if (it->action == action && (!request || it->request == request))
                { auto result = *it; inbox.erase(it); return result; }
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
        }
        throw std::runtime_error(name + " timed out waiting for action " + std::to_string(int(action)));
    }
};

int main(int argc, char** argv)
{
    try
    {
        CHECK(argc == 2);
        Client a("Speaker"), b("Listener"), distant("Far"), otherCell("Other cell");
        a.connect(argv[1]); b.connect(argv[1]); distant.connect(argv[1]); otherCell.connect(argv[1]);
        Message request;
        request.action = Action::Request;
        request.request = 1;
        request.actor.cell = "dialogue test";
        request.actor.refId = "test npc";
        request.actor.name = "Test NPC";
        request.actor.refNum = 123;
        a.send(request);
        auto owner = a.wait(Action::Open, 1);
        auto listener = b.wait(Action::Open);
        CHECK(owner.owner && !listener.owner && owner.session == listener.session);
        distant.send(request); CHECK(distant.wait(Action::Denied, 1).session == 0);
        otherCell.send(request); CHECK(otherCell.wait(Action::Denied, 1).session == 0);
        Message append;
        append.action = Action::Append;
        append.session = owner.session;
        Entry greeting; greeting.text = "Welcome. Here are your orders."; greeting.margin = false;
        append.entries = {greeting};
        a.send(append);
        CHECK(b.wait(Action::Append).entries[0].text == greeting.text);
        Entry quest; quest.title = "Orders"; quest.text = "Full story, before the shared journal update.";
        append.entries = {quest}; a.send(append);
        CHECK(b.wait(Action::Append).entries[0].text == quest.text);
        Message state; state.action = Action::State; state.session = owner.session;
        state.status = "Bartering"; state.choices = {"Yes", "No"};
        const std::vector<std::string> topics = {"background", "orders", u8"étranger"};
        state.topics = topics;
        a.send(state);
        auto shown = b.wait(Action::State);
        CHECK(shown.status == "Bartering" && shown.topics == topics);

        // A listener cannot append text, change state, or close the owner's session.
        Entry forged; forged.text = "FORGED"; append.entries = {forged}; b.send(append);
        state.status = "FORGED"; state.topics = {"FORGED"}; b.send(state);
        Message end; end.action = Action::End; end.session = owner.session; b.send(end);
        Message leave; leave.action = Action::Leave; leave.session = owner.session; b.send(leave);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        Entry absent; absent.text = "This happened while the listener was away.";
        append.entries = {absent}; a.send(append);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        b.pump(); CHECK(b.inbox.empty());
        request.request = 2; b.send(request);
        auto replay = b.wait(Action::Open, 2);
        CHECK(!replay.owner && replay.entries.size() == 3);
        CHECK(replay.entries[1].text == quest.text && replay.entries[2].text == absent.text);
        CHECK(replay.status == "Bartering" && replay.choices.size() == 2);
        CHECK(replay.topics == topics);
        CHECK(!replay.entries[0].margin);

        state.status = "Talking"; state.topics = {"newly discovered topic"};
        a.send(state); CHECK(b.wait(Action::State).topics == state.topics);
        b.send(leave);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        state.topics.push_back("discovered while absent"); a.send(state);
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        request.request = 20; b.send(request);
        CHECK(b.wait(Action::Open, 20).topics == state.topics);
        state.topics.clear(); a.send(state);
        CHECK(b.wait(Action::State).topics.empty());

        // A listener leaving the cell does not end the speaker's conversation.
        b.changeCell("leave"); b.wait(Action::End);
        b.changeCell("return"); request.request = 10; b.send(request);
        CHECK(b.wait(Action::Open, 10).entries.size() == 3);
        a.changeCell("leave"); a.wait(Action::End); b.wait(Action::End);
        a.changeCell("return"); request.request = 11; a.send(request);
        auto afterMove = a.wait(Action::Open, 11); b.wait(Action::Open);
        CHECK(afterMove.owner && afterMove.session != owner.session);

        RakNet::BitStream death;
        a.header(death, ID_PLAYER_DEATH);
        death.Write(char(1)); death.Write(true); death.Write(a.peer->GetMyGUID());
        a.transmit(death); a.wait(Action::End); b.wait(Action::End);
        RakNet::BitStream resurrect;
        a.header(resurrect, ID_PLAYER_RESURRECT); resurrect.Write(int(0)); a.transmit(resurrect);
        request.request = 12; a.send(request);
        auto afterDeath = a.wait(Action::Open, 12); b.wait(Action::Open);
        CHECK(afterDeath.owner && afterDeath.session != afterMove.session);
        end.session = afterDeath.session;
        a.send(end); b.wait(Action::End); a.wait(Action::End);

        // Competing requests obtain exactly one owner, including after re-opening.
        request.request = 3; a.send(request); b.send(request);
        auto first = a.wait(Action::Open, 3);
        auto second = b.wait(Action::Open, 3);
        CHECK(first.owner != second.owner && first.session == second.session);
        CHECK(first.session != owner.session);
        CHECK(first.entries.empty() && second.entries.empty());
        Client& speaker = first.owner ? a : b;
        Client& audience = first.owner ? b : a;
        audience.inbox.clear();
        speaker.peer->CloseConnection(speaker.server, true);
        audience.wait(Action::End);
        request.request = 4; audience.send(request);
        CHECK(audience.wait(Action::Open, 4).owner); // disconnect released NPC lock
        std::cout << checks << " live server network checks passed\n";
        return 0;
    }
    catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
