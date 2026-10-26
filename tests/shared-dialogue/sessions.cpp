#include <components/openmw-mp/Dialogue.hpp>
#include <cstdlib>
#include <iostream>
#include <limits>

using namespace mwmp::dialogue;
int checks = 0;
#define CHECK(condition) do { ++checks; if (!(condition)) { \
    std::cerr << "FAIL line " << __LINE__ << ": " #condition << '\n'; std::exit(1); } } while (false)

Actor actor(std::string cell, unsigned int number)
{
    Actor result;
    result.cell = cell;
    result.refId = "caius cosades";
    result.name = "Caius Cosades";
    result.refNum = number;
    return result;
}

int main()
{
    Sessions sessions;
    auto caius = actor("balmora, caius cosades' house", 100);
    const auto id = sessions.open(1, caius, "Speaker")->id;
    CHECK(sessions.owns(1));
    CHECK(sessions.open(2, caius, "Listener")->id == id); // simultaneous activation
    CHECK(sessions.find(id)->owner == 1); // only one greeting may execute
    CHECK(sessions.join(id, 2));
    CHECK(!sessions.join(id, 1));
    CHECK(sessions.participates(2));
    CHECK(!sessions.owns(2));
    Entry greeting;
    greeting.text = "Welcome. Tell me about your orders.";
    greeting.margin = false;
    CHECK(sessions.append(id, 1, greeting));
    Entry quest;
    quest.title = "Orders";
    quest.text = "Here is the full quest dialogue, before the journal changed.";
    CHECK(!sessions.append(id, 2, quest));
    CHECK(!sessions.state(id, 2, "Forged", {"Yes"}, {"forged topic"}));
    CHECK(!sessions.end(id, 2));
    CHECK(sessions.append(id, 1, quest));
    const std::vector<std::string> topics = {"background", "orders", u8"étranger"};
    CHECK(sessions.state(id, 1, "Bartering", {"Yes", "No"}, topics));
    CHECK(!sessions.state(id, 2, "Forged", {}, {"forged topic"}));
    sessions.leave(2);
    CHECK(!sessions.participates(2));
    CHECK(sessions.find(id)->history.size() == 2);
    Entry whileAbsent;
    whileAbsent.text = "The listener was away for this part.";
    CHECK(sessions.append(id, 1, whileAbsent));
    CHECK(sessions.join(id, 2));
    CHECK(sessions.find(id)->history.size() == 3);
    CHECK(sessions.find(id)->history[1].text == quest.text);
    CHECK(!sessions.find(id)->history[0].margin);
    CHECK(sessions.find(id)->choices.size() == 2);
    CHECK(sessions.find(id)->status == "Bartering");
    CHECK(sessions.find(id)->topics == topics);
    CHECK(!sessions.state(id, 1, "Invalid", {}, std::vector<std::string>(MaxTopics + 1, "topic")));
    CHECK(!sessions.state(id, 1, "Invalid", {}, {std::string(MaxString + 1, 'x')}));
    CHECK(!sessions.state(id, 1, "Invalid", {},
        std::vector<std::string>(MaxTopicBytes / MaxString + 1, std::string(MaxString, 'x'))));
    CHECK(sessions.find(id)->topics == topics && sessions.find(id)->status == "Bartering");
    CHECK(sessions.find(id)->choices.size() == 2); // invalid state cannot partially replace valid state
    CHECK(sessions.state(id, 1, "Talking", {}, {}));
    CHECK(sessions.find(id)->topics.empty());

    // Distinct placed copies of the same NPC must not share a lock.
    auto duplicate = caius;
    duplicate.refNum = 101;
    CHECK(sessions.open(1, duplicate, "Speaker") == nullptr); // owner cannot run two
    auto second = sessions.open(3, duplicate, "Other speaker")->id;
    CHECK(second != id);
    CHECK(!sessions.join(second, 1));
    CHECK(sessions.join(second, 2));
    CHECK(sessions.find(id)->listeners.empty());
    CHECK(sessions.find(second)->listeners.count(2) == 1);
    auto moved = caius;
    moved.cell = "another cell";
    CHECK(sessions.forActor(moved) == nullptr);
    auto spawned = caius;
    spawned.mpNum = 42;
    CHECK(sessions.forActor(spawned) == nullptr);

    CHECK(sessions.end(id, 1));
    CHECK(!sessions.find(id));
    CHECK(!sessions.append(id, 1, quest)); // late update cannot revive a session
    CHECK(!sessions.join(id, 2));
    auto fresh = sessions.open(2, caius, "New speaker")->id;
    CHECK(fresh != id);
    CHECK(sessions.find(fresh)->history.empty());

    CHECK(DefaultRadius == 420.f);
    float position[3] = {420, 0, 0};
    CHECK(inRange(caius, caius.cell, position, DefaultRadius));
    position[0] = 420.1f;
    CHECK(!inRange(caius, caius.cell, position, DefaultRadius));
    position[0] = 0;
    CHECK(!inRange(caius, "other cell", position, DefaultRadius));
    position[2] = 421;
    CHECK(!inRange(caius, caius.cell, position, DefaultRadius)); // true 3D distance
    position[2] = std::numeric_limits<float>::quiet_NaN();
    CHECK(!inRange(caius, caius.cell, position, DefaultRadius));
    position[2] = 0;
    CHECK(!inRange(caius, caius.cell, position, -1));
    CHECK(!inRange(caius, caius.cell, position, std::numeric_limits<float>::infinity()));

    Entry oversized;
    oversized.text.assign(MaxString + 1, 'x');
    CHECK(!sessions.append(fresh, 2, oversized));
    CHECK(sessions.find(fresh)->history.empty());
    CHECK(!sessions.state(fresh, 2, "Talking", std::vector<std::string>(MaxChoices + 1, "choice"), {}));
    Entry large;
    large.text.assign(MaxString, 'x');
    for (std::size_t i = 0; i < MaxHistoryBytes / MaxString; ++i) CHECK(sessions.append(fresh, 2, large));
    CHECK(!sessions.append(fresh, 2, greeting));
    CHECK(sessions.find(fresh)->bytes == MaxHistoryBytes); // never silently trim replay
    CHECK(sessions.end(fresh, 2));
    fresh = sessions.open(2, caius, "Speaker")->id;
    for (std::size_t i = 0; i < MaxEntries; ++i) CHECK(sessions.append(fresh, 2, Entry()));
    CHECK(!sessions.append(fresh, 2, Entry()));
    std::cout << checks << " shared dialogue checks passed\n";
}
