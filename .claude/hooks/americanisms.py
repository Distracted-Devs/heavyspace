"""Reports American spellings in GDScript we write.

Usage: americanisms.py <files...>. Prints one line per hit, nothing if clean.

Only checks what the project names: declared identifiers (var, const, func,
signal, class_name, enum and function parameters), comments and
@export_group/@export_subgroup labels. Godot's own API (Color, normalized())
is used, not declared, so it isn't flagged.
"""

import re
import sys

STEMS = {
    "color": "colour",
    "behavior": "behaviour",
    "honor": "honour",
    "favor": "favour",
    "favorite": "favourite",
    "armor": "armour",
    "neighbor": "neighbour",
    "center": "centre",
    "fiber": "fibre",
    "kilometer": "kilometre",
    "defense": "defence",
    "gray": "grey",
    "catalog": "catalogue",
    "maneuver": "manoeuvre",
}
ISE_STEMS = [
    "initializ", "normaliz", "optimiz", "organiz", "finaliz", "serializ",
    "visualiz", "randomiz", "minimiz", "maximiz", "utiliz", "customiz",
    "synchroniz", "prioritiz", "recogniz", "realiz", "stabiliz",
    "parameteriz", "categoriz", "authoriz", "materializ", "specializ",
    "summariz", "analyz",
]
DOUBLED_L = {
    "labeled": "labelled", "labeling": "labelling",
    "traveled": "travelled", "traveling": "travelling",
    "canceled": "cancelled", "canceling": "cancelling",
    "modeled": "modelled", "modeling": "modelling",
    "fueled": "fuelled", "fueling": "fuelling",
    "signaled": "signalled", "signaling": "signalling",
    "leveled": "levelled", "leveling": "levelling",
}

DECLARATION = re.compile(
    r"^\s*(?:static\s+)?(?:var|const|func|signal|class_name|enum)\s+(\w+)"
)
PARAMETERS = re.compile(r"^\s*(?:static\s+)?func\s+\w+\s*\(([^)]*)")
GROUP = re.compile(r"@export_(?:sub)?group\(\s*\"([^\"]*)\"")
STRING = re.compile(r"\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'")


def british(word):
    word = word.lower()
    for stem, fix in STEMS.items():
        if word == stem or (word.startswith(stem) and
                            word[len(stem):] in ("s", "ed", "ing", "ize", "ise")):
            return fix + word[len(stem):]
    for stem in ISE_STEMS:
        if word.startswith(stem):
            return stem[:-1] + "s" + word[len(stem):]
    return DOUBLED_L.get(word)


def words(name):
    return re.split(r"_|(?<=[a-z0-9])(?=[A-Z])", name)


def scan(path):
    hits = []
    with open(path, encoding="utf-8") as source:
        for number, line in enumerate(source, 1):
            found = []
            declared = DECLARATION.match(line)
            if declared:
                found += words(declared.group(1))
            parameters = PARAMETERS.match(line)
            if parameters:
                for name in re.findall(r"(?:^|,)\s*(\w+)", parameters.group(1)):
                    found += words(name)
            for label in GROUP.findall(line):
                found += re.findall(r"[A-Za-z]+", label)
            code = STRING.sub('""', line)
            if "#" in code:
                found += re.findall(r"[A-Za-z]+", code.split("#", 1)[1])
            for word in found:
                fix = british(word)
                if fix:
                    hits.append(f"{path}:{number}: '{word}' should be '{fix}'")
    return hits


if __name__ == "__main__":
    for path in sys.argv[1:]:
        for hit in scan(path):
            print(hit)
