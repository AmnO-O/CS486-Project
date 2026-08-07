#!/usr/bin/env python3
"""CS486 G05 - Task 14 deterministic data generator (Phase 2).

Writes one delimiter-safe CSV per table for the migrated Phase 2 schema. Standard library only.

Contract highlights (see README.md for the full rationale):
  * one top-level seed; every stream is derived from it, no unseeded RNG;
  * pre-assigned surrogate ids in an isolated key range so the dataset can be
    loaded next to the Task 06 sample rows (load.sql uses KEEPIDENTITY);
  * the reserved system user -1 is NEVER emitted here; it is seeded by
    outputs/10-schema-migration-G05.sql and only referenced as approver_id;
  * maintenance.impact_level is always written explicitly (the column DEFAULT is
    'out-of-service', so omitting it would silently create blocking tickets);
  * maintenance_impact_history is NOT generated: the Task 10 trigger is
    AFTER UPDATE only, so escalation history is produced by load.sql updating
    impact_level on active tickets.

Usage:
    python generate.py --config config.example.json
    python generate.py --config config.example.json --out /tmp/smoke --bookings 3000
"""

from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import json
import os
import random
import sys
from datetime import date, datetime, timedelta

SLOT_MINUTES = 30
DAY_START_HOUR = 7
DAY_END_HOUR = 18
SLOTS_PER_DAY = (DAY_END_HOUR - DAY_START_HOUR) * 60 // SLOT_MINUTES

CONFIRMED = ("approved", "checked_in", "completed")

SPACE_TYPES = (
    "auditorium",
    "classroom",
    "computer_lab",
    "project_lab",
    "meeting_room",
    "student_workspace",
)
INSTANT_ELIGIBLE = ("classroom", "computer_lab", "project_lab", "meeting_room")
PURPOSES = (
    "lecture",
    "examination",
    "seminar",
    "workshop",
    "meeting",
    "student_activity",
    "administrative_event",
)
BUILDINGS = (
    "Alpha Building",
    "Beta Building",
    "Gamma Building",
    "Delta Building",
    "Library Annex",
    "Innovation Hub",
)
FACILITY_NAMES = (
    "Projector",
    "Whiteboard",
    "Microphone",
    "Desktop Computer",
    "Livestreaming Kit",
    "Air Conditioner",
    "Document Camera",
    "Smart TV",
    "Lab Bench Power",
    "Video Conference Unit",
    "Sound Mixer",
    "Presenter Remote",
)
DEPARTMENT_NAMES = (
    "School of Computer Science",
    "Department of Mathematics",
    "Department of Physics",
    "Faculty of Engineering",
    "School of Business",
    "Faculty of Applied Sciences",
    "Department of Linguistics",
    "School Administration",
)
GIVEN_NAMES = (
    "An", "Binh", "Chi", "Dung", "Giang", "Hanh", "Hieu", "Khanh", "Lan", "Linh",
    "Minh", "Nam", "Ngoc", "Oanh", "Phuc", "Quang", "Son", "Thao", "Trang", "Vinh",
)
FAMILY_NAMES = (
    "Nguyen", "Tran", "Le", "Pham", "Hoang", "Vu", "Dang", "Bui", "Do", "Ngo",
)
ADVISORY_PROBLEMS = (
    "Projector lamp dim; slides readable but washed out",
    "One of four air conditioners is not cooling",
    "Whiteboard surface damaged on the left panel",
    "Two ceiling lights flicker intermittently",
    "Presenter remote receiver unreliable",
    "Window blind stuck in the half-open position",
)
OOS_PROBLEMS = (
    "Electrical rewiring of the whole room",
    "Floor replacement across the entire space",
    "Air-conditioning system replacement",
    "Ceiling water damage under structural repair",
    "Fire-safety remediation ordered by inspection",
    "Full furniture replacement and repainting",
)
RESULT_NOTES = (
    "Parts replaced and tested",
    "Contractor signed off the work",
    "Verified by facility staff walkthrough",
    "Temporary fix applied; monitored for one week",
)
CONDITIONS = (
    "Clean, all equipment functional",
    "Minor scuffs on the floor, equipment fine",
    "Air conditioning noisy but operational",
    "All chairs present and undamaged",
    "Whiteboard markers missing",
)
USAGE_NOTES = (
    "Session ran to schedule",
    "Ended ten minutes early",
    "Extra chairs brought in",
    "Projector needed a restart",
    "No issues reported",
)

DEFAULTS = {
    "seed": 20260807,
    "output_dir": "outputs/14-data-generator-G05/_generated",
    "id_base": 200000,
    "calendar": {
        "academic_years": [
            {"label": "AY2021-2022", "start": "2021-09-06", "end": "2022-06-25"},
            {"label": "AY2022-2023", "start": "2022-09-05", "end": "2023-06-24"},
            {"label": "AY2023-2024", "start": "2023-09-04", "end": "2024-06-22"},
            {"label": "AY2024-2025", "start": "2024-09-02", "end": "2025-06-21"},
        ],
        "term_start_spike_days": 21,
        "term_start_spike_weight": 4,
    },
    "counts": {
        "departments": 8,
        "users": 2200,
        "spaces": 120,
        "facilities": 12,
        "maintenance": 2600,
        "bookings": 120000,
    },
    "status_weights": {
        "completed": 52,
        "approved": 11,
        "checked_in": 4,
        "cancelled": 9,
        "rejected": 7,
        "pending": 12,
        "no_show": 5,
    },
    "instant_share": 0.10,
    "maintenance": {
        "advisory_share": 0.55,
        "resolved_share": 0.62,
        "soft_deleted_share": 0.04,
        "escalation_candidates": 6,
    },
    "space_status": {
        "temporarily_closed": 4,
        "retired": 3,
    },
    "batch_size": 20000,
    "csv": {"delimiter": ",", "line_terminator": "\n"},
}

TABLES = (
    "departments",
    "users",
    "spaces",
    "facilities",
    "space_facilities",
    "maintenance",
    "bookings",
    "booking_approvals",
    "booking_sessions",
    "booking_advisory_acknowledgement",
)

HEADERS = {
    # Physical column order matters: BULK INSERT maps CSV fields by ordinal.
    "departments": ("department_id", "name", "created_at", "updated_at"),
    "users": (
        "user_id", "email", "full_name", "phone_number", "role",
        "department_id", "account_status", "created_at", "updated_at",
    ),
    "spaces": (
        "space_id", "space_code", "space_name", "space_type", "building",
        "floor", "room_number", "capacity", "current_status", "usage_policy",
        "created_at", "updated_at",
    ),
    "facilities": ("facility_id", "name", "created_at", "updated_at"),
    "space_facilities": ("space_id", "facility_id", "quantity"),
    # impact_level is LAST: Task 10 added it with ALTER TABLE ADD.
    "maintenance": (
        "maintenance_id", "space_id", "reporter_id", "assigned_staff_id",
        "problem_description", "start_time", "completion_time", "status",
        "result_note", "is_deleted", "created_at", "updated_at", "impact_level",
    ),
    "bookings": (
        "booking_id", "space_id", "requester_id", "requested_start_time",
        "requested_end_time", "purpose", "expected_participants", "status",
        "is_deleted", "created_at", "updated_at",
    ),
    "booking_approvals": (
        "approval_id", "booking_id", "approver_id", "decision_time", "decision",
        "rejection_reason", "decision_note", "created_at", "updated_at",
    ),
    "booking_sessions": (
        "session_id", "booking_id", "actual_start_time", "checked_in_by",
        "initial_condition", "actual_end_time", "final_condition", "usage_notes",
        "created_at", "updated_at",
    ),
    "booking_advisory_acknowledgement": (
        "ack_id", "booking_id", "maintenance_id", "acknowledged_at",
        "acknowledged_by", "created_at", "updated_at",
    ),
}

def deep_merge(base, override):
    result = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def load_config(path):
    with open(path, "r", encoding="utf-8") as handle:
        supplied = json.load(handle)
    return deep_merge(DEFAULTS, supplied)


def parse_iso_day(value):
    return date.fromisoformat(value)


def iso_dt(value):
    return value.strftime("%Y-%m-%dT%H:%M:%S")


def sql_value(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "1" if value else "0"
    text = str(value)
    # SQL1-compatible loader uses legacy FIELDTERMINATOR parsing instead of
    # FORMAT='CSV', so generated text must never contain delimiter/control chars.
    text = text.replace("\r", " ").replace("\n", " ").replace("\t", " ")
    text = text.replace(",", ";").replace('"', "'")
    while "  " in text:
        text = text.replace("  ", " ")
    return text.strip()


def stable_rng(seed, label):
    digest = hashlib.sha256(f"{seed}:{label}".encode("ascii")).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


def weighted_choice(rng, weights):
    total = sum(weights.values())
    if total <= 0:
        raise ValueError("weights must have a positive total")
    cursor = rng.uniform(0, total)
    for key, weight in weights.items():
        cursor -= weight
        if cursor <= 0:
            return key
    return next(reversed(weights))


def weighted_status(status_weights, rng):
    return weighted_choice(rng, status_weights)


def all_workdays(calendar):
    spans = []
    for year in calendar["academic_years"]:
        current = parse_iso_day(year["start"])
        end = parse_iso_day(year["end"])
        while current <= end:
            if current.weekday() < 6:
                spans.append((current, year["label"]))
            current += timedelta(days=1)
    if not spans:
        raise ValueError("calendar produced no working days")
    return spans


def build_day_weights(workdays, calendar):
    """Precompute the per-day sampling weights once, as a cumulative table.

    Rebuilding the weight vector per booking is O(days) per draw; with ~2,800
    working days and 120k bookings that is hundreds of millions of operations.
    The cumulative table turns each draw into a bisect lookup."""
    spike_days = calendar.get("term_start_spike_days", 21)
    spike_weight = calendar.get("term_start_spike_weight", 4)
    starts = [parse_iso_day(year["start"]) for year in calendar["academic_years"]]
    cumulative = []
    running = 0
    for day, _label in workdays:
        near_start = any(abs((day - start).days) < spike_days for start in starts)
        running += spike_weight if near_start else 1
        cumulative.append(running)
    return cumulative


def choose_day(rng, workdays, cumulative_weights):
    target = rng.uniform(0, cumulative_weights[-1])
    index = bisect.bisect_left(cumulative_weights, target)
    if index >= len(workdays):
        index = len(workdays) - 1
    return workdays[index]


def make_timestamp(day, slot):
    hour = DAY_START_HOUR + (slot * SLOT_MINUTES) // 60
    minute = (slot * SLOT_MINUTES) % 60
    return datetime(day.year, day.month, day.day, hour, minute)


def pick_duration_slots(rng):
    return rng.choices((2, 3, 4, 6), weights=(44, 28, 20, 8), k=1)[0]


def random_person(rng, ordinal):
    given = GIVEN_NAMES[rng.randrange(len(GIVEN_NAMES))]
    family = FAMILY_NAMES[rng.randrange(len(FAMILY_NAMES))]
    return given, family, f"t14.{given.lower()}.{family.lower()}.{ordinal}@campus.edu"


def pct_count(total, share):
    return max(0, min(total, int(round(total * share))))


def make_master_data(config):
    seed = config["seed"]
    base = int(config["id_base"])
    counts = config["counts"]
    now = datetime(2025, 7, 1, 12, 0, 0)
    departments = []
    for index, name in enumerate(DEPARTMENT_NAMES[: counts["departments"]], start=1):
        departments.append({
            "department_id": base + index,
            "name": f"T14 {name}",
            "created_at": iso_dt(now),
            "updated_at": iso_dt(now),
        })

    users = []
    roles = (
        ("student", 70),
        ("lecturer", 10),
        ("teaching_assistant", 7),
        ("facility_staff", 7),
        ("department_admin", 4),
        ("facility_manager", 2),
    )
    role_weights = dict(roles)
    status_weights = {"active": 92, "inactive": 4, "suspended": 4}
    user_rng = stable_rng(seed, "users")
    for offset in range(counts["users"]):
        user_id = base + 1000 + offset
        given, family, email = random_person(user_rng, offset + 1)
        role = weighted_choice(user_rng, role_weights)
        account_status = weighted_choice(user_rng, status_weights)
        if role in ("facility_staff", "facility_manager"):
            account_status = "active"
        users.append({
            "user_id": user_id,
            "email": email,
            "full_name": f"{given} {family}",
            "phone_number": f"+84-90-{1000000 + offset:07d}" if offset % 11 else None,
            "role": role,
            "department_id": departments[offset % len(departments)]["department_id"],
            "account_status": account_status,
            "created_at": iso_dt(now - timedelta(days=user_rng.randrange(0, 1700))),
            "updated_at": iso_dt(now),
        })

    facilities = []
    for index, name in enumerate(FACILITY_NAMES[: counts["facilities"]], start=1):
        facilities.append({
            "facility_id": base + 4000 + index,
            "name": f"T14 {name}",
            "created_at": iso_dt(now),
            "updated_at": iso_dt(now),
        })

    space_rng = stable_rng(seed, "spaces")
    spaces = []
    space_facilities = []
    forced_types = list(SPACE_TYPES)
    closed_count = int(config["space_status"]["temporarily_closed"])
    retired_count = int(config["space_status"]["retired"])
    for offset in range(counts["spaces"]):
        space_id = base + 5000 + offset
        space_type = forced_types[offset] if offset < len(forced_types) else space_rng.choice(SPACE_TYPES)
        capacity_ranges = {
            "auditorium": (180, 450), "classroom": (25, 90),
            "computer_lab": (20, 70), "project_lab": (15, 55),
            "meeting_room": (8, 35), "student_workspace": (30, 130),
        }
        low, high = capacity_ranges[space_type]
        capacity = space_rng.randrange(low // 5, high // 5 + 1) * 5
        if offset < closed_count:
            current_status = "temporarily_closed"
        elif offset < closed_count + retired_count:
            current_status = "retired"
        else:
            current_status = "available"
        building = BUILDINGS[offset % len(BUILDINGS)]
        room_number = f"{100 + (offset % 700):03d}"
        spaces.append({
            "space_id": space_id,
            "space_code": f"T14-{building[:2].upper()}-{offset + 1:04d}",
            "space_name": f"{space_type.replace('_', ' ').title()} {room_number}",
            "space_type": space_type,
            "building": building,
            "floor": str(1 + (offset % 6)),
            "room_number": room_number,
            "capacity": capacity,
            "current_status": current_status,
            "usage_policy": (
                "Academic use has priority during teaching hours."
                if space_type != "student_workspace" else "Open collaboration; keep noise moderate."
            ),
            "created_at": iso_dt(now),
            "updated_at": iso_dt(now),
        })
        facility_count = 2 + space_rng.randrange(5)
        selected = space_rng.sample(facilities, k=min(facility_count, len(facilities)))
        for facility in selected:
            quantity = None if space_rng.random() < 0.20 else 1 + space_rng.randrange(5)
            space_facilities.append({
                "space_id": space_id,
                "facility_id": facility["facility_id"],
                "quantity": quantity,
            })

    return departments, users, spaces, facilities, space_facilities


def choose_user(users, rng, roles=None, active_only=False):
    candidates = users
    if roles:
        candidates = [user for user in candidates if user["role"] in roles]
    if active_only:
        candidates = [user for user in candidates if user["account_status"] == "active"]
    if not candidates:
        raise ValueError(f"no user available for roles={roles}, active_only={active_only}")
    return candidates[rng.randrange(len(candidates))]


def make_maintenance(config, users, spaces, workdays):
    rng = stable_rng(config["seed"], "maintenance")
    base = int(config["id_base"])
    count = int(config["counts"]["maintenance"])
    advisory_share = float(config["maintenance"]["advisory_share"])
    resolved_share = float(config["maintenance"]["resolved_share"])
    deleted_share = float(config["maintenance"]["soft_deleted_share"])
    staff_roles = ("facility_staff",)
    rows = []
    for offset in range(count):
        maintenance_id = base + 7000 + offset
        space = spaces[rng.randrange(len(spaces))]
        day, _label = workdays[rng.randrange(len(workdays))]
        start = datetime(day.year, day.month, day.day, 7 + rng.randrange(8), 0)
        impact = "advisory" if rng.random() < advisory_share else "out-of-service"
        is_resolved = rng.random() < resolved_share
        status = "resolved" if is_resolved else ("in_progress" if rng.random() < 0.50 else "open")
        completion = start + timedelta(days=2 + rng.randrange(12)) if is_resolved else None
        reporter = choose_user(users, rng, active_only=False)
        assigned = choose_user(users, rng, roles=staff_roles, active_only=True)
        rows.append({
            "maintenance_id": maintenance_id,
            "space_id": space["space_id"],
            "reporter_id": reporter["user_id"],
            "assigned_staff_id": assigned["user_id"],
            "problem_description": rng.choice(ADVISORY_PROBLEMS if impact == "advisory" else OOS_PROBLEMS),
            "start_time": iso_dt(start),
            "completion_time": iso_dt(completion) if completion else None,
            "status": status,
            "result_note": rng.choice(RESULT_NOTES) if is_resolved else None,
            "is_deleted": 1 if rng.random() < deleted_share else 0,
            "created_at": iso_dt(start - timedelta(days=rng.randrange(0, 30))),
            "updated_at": iso_dt(completion or start),
            "impact_level": impact,
        })
    return rows

def maintenance_indexes(maintenance):
    active_advisories = {}
    active_oos = {}
    for row in maintenance:
        if row["is_deleted"] or row["status"] not in ("open", "in_progress"):
            continue
        target = active_advisories if row["impact_level"] == "advisory" else active_oos
        target.setdefault(row["space_id"], []).append(row)
    return active_advisories, active_oos


def overlaps(start, end, other_start, other_end):
    return start < other_end and other_start < end


def parse_dt(value):
    return datetime.fromisoformat(value) if isinstance(value, str) else value


def make_bookings(config, users, spaces, maintenance, workdays):
    day_weights = build_day_weights(workdays, config["calendar"])
    rng = stable_rng(config["seed"], "bookings")
    base = int(config["id_base"])
    count = int(config["counts"]["bookings"])
    status_weights = config["status_weights"]
    if sum(status_weights.values()) <= 0:
        raise ValueError("status_weights must have a positive total")
    staff = [u for u in users if u["role"] in ("facility_staff", "facility_manager") and u["account_status"] == "active"]
    active_requesters = [u for u in users if u["account_status"] == "active" and u["role"] in ("student", "lecturer", "teaching_assistant", "department_admin")]
    if not staff or not active_requesters:
        raise ValueError("generator requires active requesters and staff approvers")
    active_advisories, active_oos = maintenance_indexes(maintenance)
    # Slot-level occupancy makes the single-threaded conflict proof O(1) per
    # candidate. All generated windows are aligned to the 30-minute grid.
    confirmed_slots = {space["space_id"]: set() for space in spaces}
    booking_rows = []
    approval_rows = []
    session_rows = []
    ack_rows = []
    target_statuses = []
    for status, weight in status_weights.items():
        target_statuses.extend([status] * int(round(count * weight / sum(status_weights.values()))))
    while len(target_statuses) < count:
        target_statuses.append(weighted_status(status_weights, rng))
    while len(target_statuses) > count:
        target_statuses.pop()
    rng.shuffle(target_statuses)

    # A bounded search over discrete slots guarantees termination even when the
    # confirmed schedule is dense. Non-confirmed demand is allowed to overlap.
    for offset, target_status in enumerate(target_statuses):
        booking_id = base + 100000 + offset
        space = spaces[rng.randrange(len(spaces))]
        requester = active_requesters[rng.randrange(len(active_requesters))]
        day, _label = choose_day(rng, workdays, day_weights)
        purpose = rng.choice(PURPOSES)
        duration = pick_duration_slots(rng)
        max_slot = SLOTS_PER_DAY - duration
        slot = rng.randrange(max_slot + 1)
        start = make_timestamp(day, slot)
        end = start + timedelta(minutes=duration * SLOT_MINUTES)
        space_id = space["space_id"]
        if target_status in CONFIRMED:
            accepted = False
            for attempt in range(80):
                if attempt:
                    day, _label = choose_day(rng, workdays, day_weights)
                    duration = pick_duration_slots(rng)
                    slot = rng.randrange(SLOTS_PER_DAY - duration + 1)
                    start = make_timestamp(day, slot)
                    end = start + timedelta(minutes=duration * SLOT_MINUTES)
                candidate_slots = tuple(
                    start + timedelta(minutes=SLOT_MINUTES * index)
                    for index in range(duration)
                )
                if any(slot in confirmed_slots[space_id] for slot in candidate_slots):
                    continue
                if any(overlaps(start, end, parse_dt(m["start_time"]), parse_dt(m["completion_time"]) if m["completion_time"] else end + timedelta(days=1)) for m in active_oos.get(space_id, ())):
                    continue
                accepted = True
                break
            if not accepted:
                target_status = "cancelled"
        participants = 1 + rng.randrange(max(1, space["capacity"]))
        created = start - timedelta(days=3 + rng.randrange(80), hours=rng.randrange(24))
        if target_status in CONFIRMED:
            confirmed_slots[space_id].update(
                start + timedelta(minutes=SLOT_MINUTES * index)
                for index in range(duration)
            )
        is_deleted = 1 if rng.random() < 0.012 else 0
        booking_rows.append({
            "booking_id": booking_id,
            "space_id": space_id,
            "requester_id": requester["user_id"],
            "requested_start_time": iso_dt(start),
            "requested_end_time": iso_dt(end),
            "purpose": purpose,
            "expected_participants": participants,
            "status": target_status,
            "is_deleted": is_deleted,
            "created_at": iso_dt(created),
            "updated_at": iso_dt(created),
        })
        if target_status in ("approved", "checked_in", "completed", "no_show"):
            approval_id = base + 220000 + offset
            instant = (
                space["space_type"] in INSTANT_ELIGIBLE
                and rng.random() < float(config["instant_share"])
            )
            approver = -1 if instant else staff[rng.randrange(len(staff))]["user_id"]
            decision_time = start - timedelta(days=1 + rng.randrange(20))
            approval_rows.append({
                "approval_id": approval_id,
                "booking_id": booking_id,
                "approver_id": approver,
                "decision_time": iso_dt(decision_time),
                "decision": "approved",
                "rejection_reason": None,
                "decision_note": "Instant eligibility checks passed." if instant else "Approved by facility staff.",
                "created_at": iso_dt(decision_time),
                "updated_at": iso_dt(decision_time),
            })
        elif target_status == "rejected":
            approval_id = base + 220000 + offset
            approver = staff[rng.randrange(len(staff))]["user_id"]
            decision_time = start - timedelta(days=1 + rng.randrange(20))
            approval_rows.append({
                "approval_id": approval_id,
                "booking_id": booking_id,
                "approver_id": approver,
                "decision_time": iso_dt(decision_time),
                "decision": "rejected",
                "rejection_reason": rng.choice(("Space unavailable", "Capacity or policy mismatch", "Event request declined")),
                "decision_note": "Request reviewed and rejected.",
                "created_at": iso_dt(decision_time),
                "updated_at": iso_dt(decision_time),
            })
        if target_status in ("checked_in", "completed"):
            session_id = base + 340000 + offset
            actual_start = start + timedelta(minutes=5)
            actual_end = end - timedelta(minutes=5) if target_status == "completed" else None
            checkin = staff[rng.randrange(len(staff))]["user_id"]
            session_rows.append({
                "session_id": session_id,
                "booking_id": booking_id,
                "actual_start_time": iso_dt(actual_start),
                "checked_in_by": checkin,
                "initial_condition": rng.choice(CONDITIONS),
                "actual_end_time": iso_dt(actual_end) if actual_end else None,
                "final_condition": rng.choice(CONDITIONS) if actual_end else None,
                "usage_notes": rng.choice(USAGE_NOTES),
                "created_at": iso_dt(actual_start),
                "updated_at": iso_dt(actual_end or actual_start),
            })
        # Every non-deleted confirmed booking is acknowledged against every
        # active advisory whose interval overlaps. Deleted bookings are left
        # out because the Task 14 verifier treats those rows as historical-only.
        # This is generated before approvals in the SQL load, as required by
        # trg_booking_approvals_check_space.
        if target_status in CONFIRMED and not is_deleted:
            for advisory in active_advisories.get(space_id, ()):
                advisory_end = parse_dt(advisory["completion_time"]) if advisory["completion_time"] else end + timedelta(days=1)
                if overlaps(start, end, parse_dt(advisory["start_time"]), advisory_end):
                    ack_id = base + 460000 + len(ack_rows)
                    ack_rows.append({
                        "ack_id": ack_id,
                        "booking_id": booking_id,
                        "maintenance_id": advisory["maintenance_id"],
                        "acknowledged_at": iso_dt(created + timedelta(minutes=15)),
                        "acknowledged_by": requester["user_id"],
                        "created_at": iso_dt(created + timedelta(minutes=15)),
                        "updated_at": iso_dt(created + timedelta(minutes=15)),
                    })
    # Guarantee both approval origins in every full-size run, independent of
    # random draw luck. The selected rows still satisfy the same eligibility
    # rules; only the derived origin attribution is normalized.
    booking_by_id = {row["booking_id"]: row for row in booking_rows}
    space_type_by_id = {space["space_id"]: space["space_type"] for space in spaces}
    eligible_confirmed = [
        row for row in approval_rows
        if booking_by_id[row["booking_id"]]["status"] in ("approved", "checked_in", "completed")
        and space_type_by_id[booking_by_id[row["booking_id"]]["space_id"]] in INSTANT_ELIGIBLE
    ]
    if eligible_confirmed:
        eligible_confirmed[0]["approver_id"] = -1
        eligible_confirmed[0]["decision_note"] = "Instant eligibility checks passed."
    staff_origin = next(
        (row for row in eligible_confirmed if row["booking_id"] != eligible_confirmed[0]["booking_id"]),
        None,
    ) if eligible_confirmed else None
    if staff_origin is not None:
        staff_origin["approver_id"] = staff[0]["user_id"]
        staff_origin["decision_note"] = "Approved by facility staff."
    return booking_rows, approval_rows, session_rows, ack_rows


def write_csvs(output_dir, rows_by_table, delimiter=",", line_terminator="\n"):
    os.makedirs(output_dir, exist_ok=True)
    for table in TABLES:
        path = os.path.join(output_dir, f"{table}.csv")
        with open(path, "w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle, delimiter=delimiter, lineterminator=line_terminator, quoting=csv.QUOTE_MINIMAL)
            writer.writerow(HEADERS[table])
            for row in rows_by_table.get(table, ()):
                writer.writerow([sql_value(row.get(column)) for column in HEADERS[table]])


def validate_config(config, smoke=False):
    count = int(config["counts"]["bookings"])
    if count > 500000:
        raise ValueError("counts.bookings must not exceed 500000 (Phase 2 ceiling)")
    if not smoke and count < 100000:
        raise ValueError("counts.bookings must be at least 100000 (G1); use --smoke for a reduced test run")
    if int(config["counts"]["spaces"]) < len(SPACE_TYPES):
        raise ValueError("counts.spaces must cover all six space types")
    if int(config["counts"]["facilities"]) < 6:
        raise ValueError("counts.facilities must be at least 6")
    if float(config["instant_share"]) < 0 or float(config["instant_share"]) > 1:
        raise ValueError("instant_share must be between 0 and 1")


def generate(config, smoke=False):
    validate_config(config, smoke=smoke)
    workdays = all_workdays(config["calendar"])
    departments, users, spaces, facilities, space_facilities = make_master_data(config)
    maintenance = make_maintenance(config, users, spaces, workdays)
    bookings, approvals, sessions, acks = make_bookings(config, users, spaces, maintenance, workdays)
    rows = {
        "departments": departments,
        "users": users,
        "spaces": spaces,
        "facilities": facilities,
        "space_facilities": space_facilities,
        "maintenance": maintenance,
        "bookings": bookings,
        "booking_approvals": approvals,
        "booking_sessions": sessions,
        "booking_advisory_acknowledgement": acks,
    }
    output_dir = config["output_dir"]
    write_csvs(output_dir, rows, config["csv"]["delimiter"], config["csv"]["line_terminator"])
    manifest = {
        "seed": config["seed"],
        "output_dir": os.path.abspath(output_dir),
        "tables": {table: len(rows[table]) for table in TABLES},
        "first_booking_start": min(row["requested_start_time"] for row in bookings),
        "last_booking_end": max(row["requested_end_time"] for row in bookings),
        "confirmed_count": sum(row["status"] in CONFIRMED for row in bookings),
        "ack_count": len(acks),
        "generated_by": "generate.py stdlib-only",
    }
    with open(os.path.join(output_dir, "manifest.json"), "w", encoding="ascii") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
    return manifest


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="config.example.json")
    parser.add_argument("--out", default=None, help="override config output_dir")
    parser.add_argument("--bookings", type=int, default=None, help="override counts.bookings")
    parser.add_argument(
        "--smoke",
        action="store_true",
        help="allow a booking count below the 100000 acceptance floor (test runs only)",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    config = load_config(args.config)
    if args.out:
        config["output_dir"] = args.out
    if args.bookings is not None:
        config["counts"]["bookings"] = args.bookings
    manifest = generate(config, smoke=args.smoke)
    print(json.dumps(manifest, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
