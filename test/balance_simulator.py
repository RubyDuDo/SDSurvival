#!/usr/bin/env python3
"""
OfferNotFound Monte Carlo Balance Simulator
============================================
Faithfully replicates core game mechanics for balance analysis.
Run: python3 balance_simulator.py
No external dependencies required.
"""

import random
import statistics
import sys
from dataclasses import dataclass, field
from typing import Optional

# ============================================================
#  CONSTANTS
# ============================================================

MAX_WEEKS = 12
INITIAL_CASH = 3500
WEEKLY_LIVING_COST = 500
ENERGY_PER_WEEK = 7
MAX_SKILL_LEVEL = 10
OFFER_VALIDITY_WEEKS = 3
GIG_INCOME_PARTTIME = 280
GIG_INCOME_FULLTIME = 520
GIG_ENERGY_PARTTIME = 3
GIG_ENERGY_FULLTIME = 5
STUDY_FATIGUE_THRESHOLD = 4
MAX_NETWORKING_POINTS = 10
PERSONAL_PROJECT_COST = 5
PERSONAL_PROJECT_MAX_PER_WEEK = 3
PERSONAL_PROJECT_MIN_SKILL = 5
PERSONAL_PROJECT_RESUME_BONUS = 0.15
PERSONAL_PROJECT_INTERVIEW_BONUS = 0.10

OUTSOURCE_BASE_REFRESH_CHANCE = 0.30
OUTSOURCE_REFRESH_PER_COMPLETION = 0.05
OUTSOURCE_REFRESH_MAX = 0.60
OUTSOURCE_FAIL_CHANCE = 0.15

REFERRAL_BASE_CHANCE = 0.05
REFERRAL_NETWORKING_MULT = 0.3
REFERRAL_RESUME_MULT = 1.5

MASS_APPLY_COUNT = 5

MARKET_WIND_CYCLE = 3
MARKET_WIND_CHANCE = 0.50
MARKET_EVENT_CHANCE = 0.25

TIER_CHANCE_JUNIOR_EARLY = 0.60
TIER_CHANCE_MID_EARLY = 0.30
TIER_CHANCE_SENIOR_EARLY = 0.10
TIER_CHANCE_JUNIOR_LATE = 0.35
TIER_CHANCE_MID_LATE = 0.40
TIER_CHANCE_SENIOR_LATE = 0.25

SKILL_BONUS_BACKEND_SALARY = 0.10
SKILL_BONUS_FRONTEND_INTERVIEW = 0.08
SKILL_BONUS_ALGORITHM_BIGCO = 0.15
SKILL_BONUS_DATA_OUTSOURCE = 0.15
SKILL_BONUS_DATA_OUTSOURCE_INCOME = 0.20
SKILL_BONUS_INFRA_DISAPPEAR = 0.50

NUM_SIMULATIONS = 2000

# ============================================================
#  ENUMS (as string constants)
# ============================================================

# Skills
BACKEND = "backend"
FRONTEND = "frontend"
ALGORITHM = "algorithm"
DATA_ENGINEERING = "data_engineering"
INFRASTRUCTURE = "infrastructure"
PROFESSIONAL_SKILLS = [BACKEND, FRONTEND, ALGORITHM, DATA_ENGINEERING, INFRASTRUCTURE]

COMMUNICATION = "communication"
INTERVIEW_SKILL = "interview_skill"

# Company scale
BIG = "big"
MEDIUM = "medium"
SMALL = "small"

# Benefit
BENEFIT_HIGH = "high"
BENEFIT_MEDIUM = "medium"
BENEFIT_NORMAL = "normal"

# Business status
GOOD = "good"
STABLE = "stable"
STRUGGLING = "struggling"

# Job tier
JUNIOR = "junior"
MID = "mid"
SENIOR = "senior"

# Application status
APPLIED = "applied"
HAS_INTERVIEW = "has_interview"
INTERVIEWED = "interviewed"
OFFER = "offer"
REJECTED = "rejected"

# Market wind
WIND_HOT = "hot"
WIND_SHRINK = "shrink"

# ============================================================
#  DATA DEFINITIONS
# ============================================================

BENEFIT_MULTIPLIER = {BENEFIT_HIGH: 1.15, BENEFIT_MEDIUM: 1.00, BENEFIT_NORMAL: 0.90}

@dataclass
class CompanyDef:
    id: str
    scale: str
    benefit: str
    status: str
    slots_min: int
    slots_max: int
    gen_chance: float
    disappear_chance: float
    preferred_skills: list

COMPANIES = [
    CompanyDef("bytedance", BIG, BENEFIT_HIGH, GOOD, 2, 5, 0.70, 0.10, [FRONTEND, ALGORITHM]),
    CompanyDef("deepmind", BIG, BENEFIT_HIGH, GOOD, 2, 4, 0.65, 0.12, [BACKEND, INFRASTRUCTURE]),
    CompanyDef("cybertech", MEDIUM, BENEFIT_MEDIUM, GOOD, 2, 4, 0.70, 0.15, [BACKEND, DATA_ENGINEERING]),
    CompanyDef("geekcloud", MEDIUM, BENEFIT_MEDIUM, STABLE, 1, 3, 0.65, 0.15, [FRONTEND, INFRASTRUCTURE]),
    CompanyDef("hashworks", MEDIUM, BENEFIT_NORMAL, STABLE, 2, 4, 0.65, 0.20, [ALGORITHM, DATA_ENGINEERING]),
    CompanyDef("stackflow", SMALL, BENEFIT_NORMAL, STABLE, 1, 3, 0.75, 0.20, [FRONTEND, BACKEND]),
    CompanyDef("recursion", SMALL, BENEFIT_MEDIUM, STRUGGLING, 1, 3, 0.55, 0.25, [FRONTEND, DATA_ENGINEERING]),
    CompanyDef("pointshop", SMALL, BENEFIT_NORMAL, STRUGGLING, 1, 3, 0.60, 0.25, [BACKEND, ALGORITHM]),
]

@dataclass
class SkillReq:
    skill: str
    level: int

@dataclass
class JobDef:
    id: str
    tier: str
    skill_reqs: list  # list of SkillReq
    comm_req: int
    base_salary: int

JOB_TEMPLATES = [
    # Junior
    JobDef("jr_backend", JUNIOR, [SkillReq(BACKEND, 3)], 0, 750),
    JobDef("jr_frontend", JUNIOR, [SkillReq(FRONTEND, 3)], 0, 720),
    JobDef("jr_data", JUNIOR, [SkillReq(DATA_ENGINEERING, 3)], 0, 700),
    JobDef("jr_ops", JUNIOR, [SkillReq(INFRASTRUCTURE, 3)], 1, 730),
    JobDef("jr_algo", JUNIOR, [SkillReq(ALGORITHM, 4)], 0, 850),
    # Mid
    JobDef("mid_fullstack", MID, [SkillReq(FRONTEND, 4), SkillReq(BACKEND, 3)], 2, 1100),
    JobDef("mid_search", MID, [SkillReq(ALGORITHM, 4), SkillReq(BACKEND, 3)], 2, 1200),
    JobDef("mid_data_eng", MID, [SkillReq(DATA_ENGINEERING, 4), SkillReq(BACKEND, 3)], 2, 1050),
    JobDef("mid_sre", MID, [SkillReq(INFRASTRUCTURE, 4), SkillReq(BACKEND, 3)], 3, 1100),
    JobDef("mid_bigdata", MID, [SkillReq(DATA_ENGINEERING, 4), SkillReq(INFRASTRUCTURE, 3)], 2, 1050),
    JobDef("mid_frontend", MID, [SkillReq(FRONTEND, 5)], 3, 1000),
    # Senior
    JobDef("sr_fullstack", SENIOR, [SkillReq(FRONTEND, 6), SkillReq(BACKEND, 5)], 4, 1700),
    JobDef("sr_recommend", SENIOR, [SkillReq(ALGORITHM, 6), SkillReq(BACKEND, 5)], 3, 1800),
    JobDef("sr_data_plat", SENIOR, [SkillReq(DATA_ENGINEERING, 6), SkillReq(INFRASTRUCTURE, 5)], 4, 1650),
    JobDef("sr_ai_app", SENIOR, [SkillReq(ALGORITHM, 5), SkillReq(FRONTEND, 5)], 3, 1600),
    JobDef("sr_sre", SENIOR, [SkillReq(INFRASTRUCTURE, 6), SkillReq(BACKEND, 5)], 3, 1700),
]

MARKET_EVENTS = [
    {"id": "ai_shock", "duration": 3, "tag": "ai_shock"},
    {"id": "economy_down", "duration": 3, "tag": "economy_down"},
    {"id": "policy_boost", "duration": 3, "tag": "policy_boost"},
    {"id": "funding_boom", "duration": 2, "tag": "funding_boom"},
    {"id": "industry_crackdown", "duration": 1, "tag": "industry_crackdown"},
]

# ── Tools ──

SHOP_ENERGY_COST = 1
MAX_TOOLS = 3
SHOP_DISPLAY_COUNT = 3

@dataclass
class ToolDef:
    id: str
    price: int
    weekly_cost: int

ALL_TOOLS = [
    ToolDef("mech_keyboard", 400, 0),      # Study XP +0.5 (first 2/week)
    ToolDef("headphones", 350, 0),          # Immune to negative random events
    ToolDef("ipad", 500, 0),               # +0.5 XP random skill when employed
    ToolDef("thinkpad", 500, 0),           # Outsource success +20%, income +100
    ToolDef("coffee_machine", 250, 0),     # Living cost -80/week
    ToolDef("resume_template", 200, 0),    # Resume +5%
    ToolDef("zhishixingqiu", 150, 20),     # Outsource refresh +15%, income +80
    ToolDef("nice_shirt", 300, 0),         # Interview +8%
    ToolDef("linkedin", 200, 40),          # Networking +2 instead of +1
    ToolDef("coworking", 350, 60),         # Auto +0.5 networking, gig +20%
]

# Priority tools by direction
TOOL_PRIORITY = {
    BACKEND: ["resume_template", "nice_shirt", "mech_keyboard", "coffee_machine"],
    FRONTEND: ["nice_shirt", "resume_template", "mech_keyboard", "coffee_machine"],
    ALGORITHM: ["mech_keyboard", "resume_template", "nice_shirt", "coffee_machine"],
    DATA_ENGINEERING: ["thinkpad", "zhishixingqiu", "coffee_machine", "resume_template"],
    INFRASTRUCTURE: ["resume_template", "nice_shirt", "mech_keyboard", "coffee_machine"],
}

# ============================================================
#  JOB LISTING (instantiated job)
# ============================================================

_listing_id_counter = 0

@dataclass
class JobListing:
    listing_id: str
    job_def: JobDef
    company: CompanyDef
    actual_salary: int
    actual_skill_reqs: list  # list of SkillReq
    actual_comm_req: int
    weeks_alive: int = 0

@dataclass
class Application:
    listing: JobListing
    status: str = APPLIED
    offer_weeks_left: int = 0
    is_referral: bool = False

# ============================================================
#  GAME STATE
# ============================================================

class GameState:
    def __init__(self, direction: str):
        self.week = 1
        self.cash = INITIAL_CASH
        self.energy = ENERGY_PER_WEEK
        self.direction = direction

        # Skills
        self.skills = {s: 0 for s in PROFESSIONAL_SKILLS}
        self.skill_xp = {s: 0.0 for s in PROFESSIONAL_SKILLS}
        self.skills[direction] = 3
        self.skill_xp[direction] = 0.0

        self.communication = 0
        self.communication_xp = 0.0
        self.interview_skill = 0
        self.interview_skill_xp = 0.0

        # Passive stats
        self.work_experience = 0
        self.bigco_experience = 0
        self.gap_time = 0
        self.networking_points = 0
        self.personal_project_done = False
        self.personal_project_progress = 0
        self.outsource_count = 0

        # Job state
        self.current_job: Optional[JobListing] = None
        self.applications: dict = {}  # listing_id -> Application

        # Market
        self.listings: list = []
        self.company_statuses = {c.id: c.status for c in COMPANIES}
        self.current_wind_skill: Optional[str] = None
        self.current_wind_type: Optional[str] = None
        self.wind_weeks_left = 0
        self.market_event_tag: Optional[str] = None
        self.market_event_weeks_left = 0
        self.original_statuses: dict = {}

        # Outsource
        self.current_outsource: Optional[dict] = None  # {skill, level, energy_cost, income}

        # Weekly tracking
        self.weekly_study_counts: dict = {}  # skill_key -> count
        self.weekly_study_total = 0
        self.applied_this_week: list = []
        self.interviewed_this_week: list = []
        self.pp_work_this_week = 0

        # Trait tracking
        self.traits: set = set()
        self.study_streak_weeks = 0
        self.interview_pass_count = 0
        self.total_gig_count = 0
        self.cash_above_3000_weeks = 0
        self.referral_interview_count = 0

        # Energy modifier
        self.energy_mod_next = 0

        # Stats
        self.total_offers = 0
        self.first_offer_week = None
        self.bankrupt = False
        self.employed = False

        # Tools
        self.tools: list = []  # list of tool ids
        self.shop_visited_this_week = False
        self._mech_keyboard_uses = 0

        # Listing counter
        self._listing_counter = 0

        # Initialize listings
        self._generate_all_company_listings()

    def has_tool(self, tool_id: str) -> bool:
        return tool_id in self.tools

    def action_visit_shop(self):
        """Visit shop (1 EP), buy best available tool based on direction priority."""
        if self.shop_visited_this_week:
            return False
        if self.free_energy() < SHOP_ENERGY_COST:
            return False
        self.energy -= SHOP_ENERGY_COST
        self.shop_visited_this_week = True

        # Generate 3 random tools
        available = [t for t in ALL_TOOLS if t.id not in self.tools]
        if not available:
            return True
        display = random.sample(available, min(SHOP_DISPLAY_COUNT, len(available)))

        # Buy based on priority
        if len(self.tools) >= MAX_TOOLS:
            return True  # Full, don't buy
        priority = TOOL_PRIORITY.get(self.direction, [])
        for tid in priority:
            for tool in display:
                if tool.id == tid and self.cash >= tool.price + 500:  # Keep buffer
                    self.tools.append(tool.id)
                    self.cash -= tool.price
                    return True
        # If nothing in priority list, buy cheapest useful tool
        display.sort(key=lambda t: t.price)
        for tool in display:
            if self.cash >= tool.price + 500:
                self.tools.append(tool.id)
                self.cash -= tool.price
                return True
        return True

    # ── Skill XP ──

    def _xp_needed(self, level: int) -> float:
        return float(level)

    def add_skill_xp(self, skill: str, amount: float):
        if skill in PROFESSIONAL_SKILLS:
            if self.skills[skill] >= MAX_SKILL_LEVEL:
                return
            self.skill_xp[skill] += amount
            while self.skills[skill] < MAX_SKILL_LEVEL:
                needed = self._xp_needed(self.skills[skill] + 1)
                if self.skill_xp[skill] >= needed:
                    self.skill_xp[skill] -= needed
                    self.skills[skill] += 1
                else:
                    break
            if self.skills[skill] >= MAX_SKILL_LEVEL:
                self.skill_xp[skill] = 0.0
        elif skill == COMMUNICATION:
            self.communication_xp += amount
            while self.communication < MAX_SKILL_LEVEL:
                needed = self._xp_needed(self.communication + 1)
                if self.communication_xp >= needed:
                    self.communication_xp -= needed
                    self.communication += 1
                else:
                    break
        elif skill == INTERVIEW_SKILL:
            self.interview_skill_xp += amount
            while self.interview_skill < MAX_SKILL_LEVEL:
                needed = self._xp_needed(self.interview_skill + 1)
                if self.interview_skill_xp >= needed:
                    self.interview_skill_xp -= needed
                    self.interview_skill += 1
                else:
                    break

    # ── Actions ──

    def free_energy(self) -> int:
        locked = 0
        if self.current_job:
            # Employed jobs lock energy based on tier (junior=4, mid/senior=5)
            if self.current_job.job_def.tier == JUNIOR:
                locked = 4
            else:
                locked = 5
        return self.energy - locked

    def action_study(self, skill: str):
        """Study a skill for 1 EP."""
        if self.free_energy() < 1:
            return False
        self.energy -= 1
        count = self.weekly_study_counts.get(skill, 0)
        xp = 1.0
        if count >= STUDY_FATIGUE_THRESHOLD - 1:  # 4th+ study of same skill
            xp = 0.5
        # Trait bonuses
        if "juanwang" in self.traits:
            xp += 0.5
        if "desperate" in self.traits:
            xp += 0.2
        # Mechanical keyboard: +0.5 XP first 2 uses per week
        if self.has_tool("mech_keyboard") and self._mech_keyboard_uses < 2:
            xp += 0.5
            self._mech_keyboard_uses += 1
        self.weekly_study_counts[skill] = count + 1
        self.weekly_study_total += 1
        self.add_skill_xp(skill, xp)
        return True

    def action_gig_fulltime(self):
        if self.free_energy() < GIG_ENERGY_FULLTIME:
            return False
        self.energy -= GIG_ENERGY_FULLTIME
        income = int(GIG_INCOME_FULLTIME * self._gig_multiplier())
        self.cash += income
        self.total_gig_count += 1
        return True

    def action_gig_parttime(self):
        if self.free_energy() < GIG_ENERGY_PARTTIME:
            return False
        self.energy -= GIG_ENERGY_PARTTIME
        income = int(GIG_INCOME_PARTTIME * self._gig_multiplier())
        self.cash += income
        self.total_gig_count += 1
        return True

    def _gig_multiplier(self) -> float:
        m = 1.0
        if "slasher" in self.traits:
            m += 0.25
        if "social_butterfly" in self.traits:
            m += 0.30
        if self.networking_points >= 5:
            m += 0.20  # coworking simplified: assume acquired if networking high
        return m

    def action_apply(self, listing: JobListing, mass=False):
        """Apply to a job (1 EP for focused, mass uses bulk)."""
        lid = listing.listing_id
        if lid in self.applications:
            app = self.applications[lid]
            if app.status != REJECTED:
                return False
        app = Application(listing=listing, is_referral=False)
        self.applications[lid] = app
        self.applied_this_week.append(lid)
        return True

    def action_mass_apply(self):
        """Mass apply to up to 5 random jobs (1 EP)."""
        if self.free_energy() < 1:
            return []
        self.energy -= 1
        eligible = [l for l in self.listings if l.listing_id not in self.applications
                    or self.applications[l.listing_id].status == REJECTED]
        random.shuffle(eligible)
        applied = []
        for l in eligible[:MASS_APPLY_COUNT]:
            app = Application(listing=l)
            self.applications[l.listing_id] = app
            self.applied_this_week.append(l.listing_id)
            applied.append(l)
        return applied

    def action_focused_apply(self, listing: JobListing):
        """Focused apply to one job (1 EP)."""
        if self.free_energy() < 1:
            return False
        self.energy -= 1
        return self.action_apply(listing)

    def action_interview(self, listing_id: str):
        """Interview (2 EP, or 1 EP for Infrastructure direction)."""
        cost = 1 if self.direction == INFRASTRUCTURE else 2
        if self.free_energy() < cost:
            return False
        if listing_id not in self.applications:
            return False
        app = self.applications[listing_id]
        if app.status != HAS_INTERVIEW:
            return False
        self.energy -= cost
        app.status = INTERVIEWED
        self.interviewed_this_week.append(listing_id)
        return True

    def action_accept_offer(self, listing_id: str):
        if listing_id not in self.applications:
            return False
        app = self.applications[listing_id]
        if app.status != OFFER:
            return False
        offer_salary = app.listing.actual_salary
        # Interview skill >= 4: 30% chance for +10-15%
        if self.interview_skill >= 4 and random.random() < 0.30:
            bonus = random.uniform(0.10, 0.15)
            offer_salary = int(offer_salary * (1.0 + bonus))
            app.listing.actual_salary = offer_salary
        # Negotiator trait
        if "negotiator" in self.traits:
            offer_salary = int(offer_salary * 1.10)
            app.listing.actual_salary = offer_salary
        self.current_job = app.listing
        self.networking_points = min(self.networking_points + 1, MAX_NETWORKING_POINTS)
        self.gap_time = 0
        del self.applications[listing_id]
        return True

    def action_networking(self):
        if self.free_energy() < 1:
            return False
        if self.networking_points >= MAX_NETWORKING_POINTS:
            return False
        self.energy -= 1
        self.networking_points = min(self.networking_points + 1, MAX_NETWORKING_POINTS)
        return True

    def action_personal_project(self):
        if self.personal_project_done:
            return False
        if self.pp_work_this_week >= PERSONAL_PROJECT_MAX_PER_WEEK:
            return False
        has_skill = any(self.skills[s] >= PERSONAL_PROJECT_MIN_SKILL for s in PROFESSIONAL_SKILLS)
        if not has_skill:
            return False
        if self.free_energy() < 1:
            return False
        self.energy -= 1
        self.personal_project_progress += 1
        self.pp_work_this_week += 1
        if self.personal_project_progress >= PERSONAL_PROJECT_COST:
            self.personal_project_done = True
        return True

    def action_outsource(self):
        if self.current_outsource is None:
            return False
        oc = self.current_outsource
        if self.free_energy() < oc["energy_cost"]:
            return False
        self.energy -= oc["energy_cost"]
        skill_level = self.skills[oc["skill"]]
        min_level = 4 if oc["level"] == "mid" else 6
        fail_chance = OUTSOURCE_FAIL_CHANCE if skill_level - min_level < 2 else 0.0
        if "outsource_pro" in self.traits:
            fail_chance = 0.0
        if random.random() < fail_chance:
            self.current_outsource = None
            return True  # Failed but energy spent
        income = int(oc["income"] * self._gig_multiplier())
        if self.has_tool("thinkpad"):
            income += 100
        if self.has_tool("zhishixingqiu"):
            income += 80
        if self.direction == DATA_ENGINEERING:
            income = int(income * (1.0 + SKILL_BONUS_DATA_OUTSOURCE_INCOME))
        self.cash += income
        self.outsource_count += 1
        self.total_gig_count += 1
        self.current_outsource = None
        return True

    # ── Resume / Interview pass rates ──

    def calc_resume_pass_rate(self, listing: JobListing, is_referral=False) -> float:
        skill_scores = []
        for req in listing.actual_skill_reqs:
            plv = self.skills[req.skill]
            if plv >= req.level:
                score = 0.50 + (plv - req.level) * 0.05
            else:
                score = 0.50 - (req.level - plv) * 0.15
            skill_scores.append(score)

        base_score = sum(skill_scores) / len(skill_scores) if skill_scores else 0.5

        # Comm penalty
        if self.communication < listing.actual_comm_req:
            base_score *= 0.7

        rate = base_score
        rate += self.communication * 0.02
        rate += self.networking_points * 0.03
        rate += self.work_experience * 0.02
        rate += self.bigco_experience * 0.03

        if self.gap_time > 3:
            rate -= (self.gap_time - 3) * 0.05

        if self.personal_project_done:
            rate += PERSONAL_PROJECT_RESUME_BONUS

        if self.has_tool("resume_template"):
            rate += 0.05

        # Algorithm direction + big company
        if self.direction == ALGORITHM and listing.company.scale == BIG:
            rate += SKILL_BONUS_ALGORITHM_BIGCO

        if is_referral:
            mult = 2.0 if "insider" in self.traits else REFERRAL_RESUME_MULT
            rate *= mult

        return max(0.05, min(0.95, rate))

    def calc_interview_pass_rate(self, listing: JobListing) -> float:
        rate = 0.55

        # Skill bonus
        if listing.actual_skill_reqs:
            skill_bonus = 0.0
            for req in listing.actual_skill_reqs:
                skill_bonus += (self.skills[req.skill] - req.level) * 0.08
            skill_bonus /= len(listing.actual_skill_reqs)
            rate += skill_bonus

        rate += self.interview_skill * 0.03
        rate += self.communication * 0.02
        rate += self.work_experience * 0.02
        rate += self.bigco_experience * 0.02

        if self.gap_time > 3:
            rate -= (self.gap_time - 3) * 0.03

        if self.personal_project_done:
            rate += PERSONAL_PROJECT_INTERVIEW_BONUS

        if self.has_tool("nice_shirt"):
            rate += 0.08

        # Traits
        if "mianba" in self.traits:
            rate += 0.10
        if "social_butterfly" in self.traits:
            rate += 0.05
        if "duomian" in self.traits and listing.job_def.tier == MID:
            rate += 0.10

        # Policy boost market event
        if self.market_event_tag == "policy_boost" and self.market_event_weeks_left > 0:
            rate += 0.15

        # Frontend direction
        if self.direction == FRONTEND:
            rate += SKILL_BONUS_FRONTEND_INTERVIEW

        return max(0.10, min(0.90, rate))

    # ── Week settlement ──

    def settle_week(self):
        # 1. Salary / gap
        if self.current_job:
            self.cash += self.current_job.actual_salary
            self.work_experience += 1
            if self.current_job.company.scale == BIG:
                self.bigco_experience += 1
        else:
            self.gap_time += 1

        # 2. Living cost
        living = WEEKLY_LIVING_COST
        if "conservative" in self.traits:
            living -= 50
        if self.has_tool("coffee_machine"):
            living -= 80
        self.cash -= living

        # 2.5 Tool weekly costs
        for tid in self.tools:
            for tdef in ALL_TOOLS:
                if tdef.id == tid and tdef.weekly_cost > 0:
                    self.cash -= tdef.weekly_cost

        # 3. Resume results (10% ghost, then pass rate check)
        for lid in list(self.applied_this_week):
            if lid not in self.applications:
                continue
            app = self.applications[lid]
            if app.status != APPLIED:
                continue
            # 10% ghost
            if random.random() < 0.10:
                app.status = REJECTED
                continue
            pr = self.calc_resume_pass_rate(app.listing, app.is_referral)
            if random.random() < pr:
                app.status = HAS_INTERVIEW
                if app.is_referral:
                    self.referral_interview_count += 1
            else:
                app.status = REJECTED

        # 4. Interview results
        for lid in list(self.interviewed_this_week):
            if lid not in self.applications:
                continue
            app = self.applications[lid]
            if app.status != INTERVIEWED:
                continue
            ir = self.calc_interview_pass_rate(app.listing)
            if random.random() < ir:
                app.status = OFFER
                app.offer_weeks_left = OFFER_VALIDITY_WEEKS
                self.total_offers += 1
                self.interview_pass_count += 1
                if self.first_offer_week is None:
                    self.first_offer_week = self.week
            else:
                app.status = REJECTED

        # 5. Referral check
        self._check_referral()

        # 6. Outsource refresh
        self._check_outsource_refresh()

        # 7. Offer expiry
        expired = []
        for lid, app in list(self.applications.items()):
            if app.status == OFFER:
                app.offer_weeks_left -= 1
                if app.offer_weeks_left <= 0:
                    expired.append(lid)
        for lid in expired:
            del self.applications[lid]

        # 8. Trait checks
        self._check_traits()

        # 9. Job disappearance
        surviving = []
        for listing in self.listings:
            listing.weeks_alive += 1
            if listing.listing_id in self.applications:
                surviving.append(listing)
                continue
            dc = listing.company.disappear_chance
            # Get current company status
            cs = self.company_statuses.get(listing.company.id, listing.company.status)
            if cs == STRUGGLING:
                dc += 0.10
            if random.random() >= dc:
                surviving.append(listing)
        self.listings = surviving

        # 10. Market wind / event updates
        if self.wind_weeks_left > 0:
            self.wind_weeks_left -= 1
            if self.wind_weeks_left == 0:
                self.current_wind_skill = None
                self.current_wind_type = None

        if self.market_event_weeks_left > 0:
            self.market_event_weeks_left -= 1
            if self.market_event_weeks_left == 0:
                self._end_market_event()

        # New wind every 3 weeks
        if self.week > 1 and (self.week - 1) % MARKET_WIND_CYCLE == 0 and self.wind_weeks_left == 0:
            if random.random() < MARKET_WIND_CHANCE:
                self.current_wind_skill = random.choice(PROFESSIONAL_SKILLS)
                self.current_wind_type = WIND_HOT if random.random() < 0.5 else WIND_SHRINK
                self.wind_weeks_left = MARKET_WIND_CYCLE

        # New market event
        if self.market_event_weeks_left == 0 and random.random() < MARKET_EVENT_CHANCE:
            evt = random.choice(MARKET_EVENTS)
            self.market_event_tag = evt["tag"]
            self.market_event_weeks_left = evt["duration"]
            self._apply_market_event()

        # 11. Job generation
        self._generate_all_company_listings()

        # 12. Random events (30% chance)
        if random.random() < 0.30:
            self._process_random_event()

        # 13. Trait tracking for streak
        if self.weekly_study_total >= 4:
            self.study_streak_weeks += 1
        else:
            self.study_streak_weeks = 0

        # Conservative tracking
        if self.cash > 3000:
            self.cash_above_3000_weeks += 1
        else:
            self.cash_above_3000_weeks = 0

        # 14. Game over check
        if self.cash < 0:
            self.bankrupt = True

        # 15. Advance week
        self.week += 1
        self.energy = max(1, ENERGY_PER_WEEK + self.energy_mod_next)
        self.energy_mod_next = 0
        self.weekly_study_counts.clear()
        self.weekly_study_total = 0
        self.applied_this_week.clear()
        self.interviewed_this_week.clear()
        self.pp_work_this_week = 0
        self.shop_visited_this_week = False
        self._mech_keyboard_uses = 0

    def _check_referral(self):
        if self.networking_points < 1:
            return
        chance = REFERRAL_BASE_CHANCE * (1.0 + self.networking_points * REFERRAL_NETWORKING_MULT)
        if random.random() >= chance:
            return
        eligible = [l for l in self.listings if l.listing_id not in self.applications]
        if not eligible:
            return
        listing = random.choice(eligible)
        app = Application(listing=listing, is_referral=True)
        self.applications[listing.listing_id] = app
        self.applied_this_week.append(listing.listing_id)

    def _check_outsource_refresh(self):
        self.current_outsource = None
        chance = OUTSOURCE_BASE_REFRESH_CHANCE + self.outsource_count * OUTSOURCE_REFRESH_PER_COMPLETION
        if "outsource_pro" in self.traits:
            chance += 0.20
        if self.direction == DATA_ENGINEERING:
            chance += SKILL_BONUS_DATA_OUTSOURCE
        if self.has_tool("zhishixingqiu"):
            chance += 0.15
        chance = max(0.30, min(0.75, chance))
        if random.random() >= chance:
            return
        eligible = [s for s in PROFESSIONAL_SKILLS if self.skills[s] >= 4]
        if not eligible:
            return
        skill = random.choice(eligible)
        level = "mid"
        if self.skills[skill] >= 6 and random.random() < 0.5:
            level = "high"
        ecost = random.choice([2, 3])
        if level == "mid":
            income = 350 if ecost == 2 else 500
        else:
            income = 550 if ecost == 2 else 750
        self.current_outsource = {"skill": skill, "level": level, "energy_cost": ecost, "income": income}

    def _check_traits(self):
        # Juanwang: 3 consecutive weeks studying >= 4
        if "juanwang" not in self.traits and self.study_streak_weeks >= 3:
            self.traits.add("juanwang")

        # Duomian: 3 skills >= 3
        if "duomian" not in self.traits:
            if sum(1 for s in PROFESSIONAL_SKILLS if self.skills[s] >= 3) >= 3:
                self.traits.add("duomian")

        # Mianba: 3 interview passes
        if "mianba" not in self.traits and self.interview_pass_count >= 3:
            self.traits.add("mianba")

        # Conservative: 4 weeks cash > 3000
        if "conservative" not in self.traits and self.cash_above_3000_weeks >= 4:
            self.traits.add("conservative")

        # Slasher: 8+ gig/outsource
        if "slasher" not in self.traits and self.total_gig_count >= 8:
            self.traits.add("slasher")

        # Desperate: cash < 500
        if "desperate" not in self.traits and 0 <= self.cash < 500:
            self.traits.add("desperate")
        elif "desperate" in self.traits and self.cash > 1500:
            self.traits.discard("desperate")

        # Social butterfly: networking >= 7
        if "social_butterfly" not in self.traits and self.networking_points >= 7:
            self.traits.add("social_butterfly")

        # Outsource pro: 5+ outsource
        if "outsource_pro" not in self.traits and self.outsource_count >= 5:
            self.traits.add("outsource_pro")

    def _apply_market_event(self):
        if self.market_event_tag == "ai_shock":
            self.original_statuses = dict(self.company_statuses)
            for c in COMPANIES:
                cs = self.company_statuses[c.id]
                if cs == GOOD:
                    self.company_statuses[c.id] = STABLE
                elif cs == STABLE:
                    self.company_statuses[c.id] = STRUGGLING
        elif self.market_event_tag == "funding_boom":
            self.original_statuses = dict(self.company_statuses)
            for c in COMPANIES:
                if c.scale != BIG and random.random() < 0.60:
                    cs = self.company_statuses[c.id]
                    if cs == STRUGGLING:
                        self.company_statuses[c.id] = STABLE
                    elif cs == STABLE:
                        self.company_statuses[c.id] = GOOD

    def _end_market_event(self):
        if self.market_event_tag in ("ai_shock", "funding_boom"):
            if self.original_statuses:
                self.company_statuses = dict(self.original_statuses)
                self.original_statuses = {}
        self.market_event_tag = None

    def _process_random_event(self):
        # Headphones: immune to negative random events (except quarterly bonus)
        if self.has_tool("headphones"):
            # Only positive events
            events = [
                ("gain_350", 3), ("gain_energy", 2),
                ("gain_250", 2), ("inspiration", 2),
            ]
        else:
            events = [
                ("lose_300", 3), ("lose_250", 2), ("lose_500", 2),
                ("sick", 2), ("gain_350", 3), ("gain_energy", 2),
                ("gain_250", 2), ("inspiration", 2),
            ]
        total = sum(w for _, w in events)
        r = random.randint(0, total - 1)
        cum = 0
        chosen = events[0][0]
        for eid, w in events:
            cum += w
            if r < cum:
                chosen = eid
                break

        if chosen == "lose_300":
            self.cash -= 300
        elif chosen == "lose_250":
            self.cash -= 250
        elif chosen == "lose_500":
            self.cash -= 500
        elif chosen == "sick":
            self.energy_mod_next -= 2
        elif chosen == "gain_350":
            self.cash += 350
        elif chosen == "gain_energy":
            self.energy_mod_next += 2
        elif chosen == "gain_250":
            self.cash += 250
        elif chosen == "inspiration":
            pass  # Fatigue bonus - simplified away

    def _generate_all_company_listings(self):
        for company in COMPANIES:
            # Industry crackdown
            if self.market_event_tag == "industry_crackdown" and self.market_event_weeks_left > 0:
                continue

            current_count = sum(1 for l in self.listings if l.company.id == company.id)
            max_slots = random.randint(company.slots_min, company.slots_max)
            empty_slots = max(0, max_slots - current_count)

            gen_chance = company.gen_chance
            # Wind modifier
            if self.current_wind_skill and self.wind_weeks_left > 0:
                if self.current_wind_skill in company.preferred_skills:
                    mod = 0.20 if self.current_wind_type == WIND_HOT else -0.15
                    gen_chance += mod
            # Economy down
            if self.market_event_tag == "economy_down" and self.market_event_weeks_left > 0:
                gen_chance -= 0.20
            # Business status
            cs = self.company_statuses.get(company.id, company.status)
            if cs == GOOD:
                gen_chance += 0.05
            elif cs == STRUGGLING:
                gen_chance -= 0.10
            gen_chance = max(0.05, min(0.95, gen_chance))

            for _ in range(empty_slots):
                if random.random() < gen_chance:
                    self._create_listing(company)

    def _create_listing(self, company: CompanyDef):
        # Pick tier
        if self.week <= 6:
            jc, mc = TIER_CHANCE_JUNIOR_EARLY, TIER_CHANCE_MID_EARLY
        else:
            jc, mc = TIER_CHANCE_JUNIOR_LATE, TIER_CHANCE_MID_LATE

        r = random.random()
        if r < jc:
            tier = JUNIOR
        elif r < jc + mc:
            tier = MID
        else:
            tier = SENIOR

        # Match jobs to company preferred skills
        matching = [j for j in JOB_TEMPLATES if j.tier == tier
                    and any(req.skill in company.preferred_skills for req in j.skill_reqs)]
        if not matching and tier == SENIOR:
            matching = [j for j in JOB_TEMPLATES if j.tier == MID
                        and any(req.skill in company.preferred_skills for req in j.skill_reqs)]
        if not matching:
            matching = [j for j in JOB_TEMPLATES if j.tier == JUNIOR
                        and any(req.skill in company.preferred_skills for req in j.skill_reqs)]
        if not matching:
            return

        job_def = random.choice(matching)
        self._listing_counter += 1
        lid = f"{company.id}_{job_def.id}_{self._listing_counter}"

        # Salary with company multiplier and +-10%
        sal_mult = BENEFIT_MULTIPLIER[company.benefit]
        actual_salary = round(job_def.base_salary * sal_mult * random.uniform(0.9, 1.1) / 10) * 10

        # Backend direction salary bonus
        if self.direction == BACKEND:
            for req in job_def.skill_reqs:
                if req.skill == BACKEND:
                    actual_salary = round(actual_salary * (1.0 + SKILL_BONUS_BACKEND_SALARY) / 10) * 10
                    break

        # Randomize skill reqs +/-1
        actual_reqs = []
        for req in job_def.skill_reqs:
            v = random.choice([-1, 0, 1])
            actual_reqs.append(SkillReq(req.skill, max(1, req.level + v)))

        # Randomize comm req +/-1
        actual_comm = max(0, job_def.comm_req + random.choice([-1, 0, 1]))

        listing = JobListing(
            listing_id=lid, job_def=job_def, company=company,
            actual_salary=actual_salary, actual_skill_reqs=actual_reqs,
            actual_comm_req=actual_comm
        )
        self.listings.append(listing)

    # ── Ending calculation ──

    def calc_projected_income(self) -> int:
        if self.current_job:
            return (self.current_job.actual_salary - WEEKLY_LIVING_COST) * 52 + self.cash
        best_offer = 0
        for app in self.applications.values():
            if app.status == OFFER and app.listing.actual_salary > best_offer:
                best_offer = app.listing.actual_salary
        if best_offer > 0:
            return (best_offer - WEEKLY_LIVING_COST) * 50 + self.cash
        return max(0, self.cash - WEEKLY_LIVING_COST * 12)

    def get_rank(self) -> str:
        if self.bankrupt:
            return "F"
        proj = self.calc_projected_income()
        if proj >= 50000:
            return "S"
        if proj >= 30000:
            return "A"
        if proj >= 15000:
            return "B"
        if proj >= 0:
            return "C"
        return "F"

    def get_main_skill_level(self) -> int:
        return self.skills[self.direction]


# ============================================================
#  STRATEGIES
# ============================================================

def _try_shop(gs: GameState):
    """Common: visit shop once per week if affordable."""
    if not gs.shop_visited_this_week and gs.free_energy() >= SHOP_ENERGY_COST and len(gs.tools) < MAX_TOOLS:
        gs.action_visit_shop()


def strategy_pure_gig(gs: GameState):
    """Every week: full-time gig + part-time gig. Never study or apply."""
    _try_shop(gs)
    gs.action_gig_fulltime()
    if gs.free_energy() >= GIG_ENERGY_PARTTIME:
        gs.action_gig_parttime()


def strategy_study_first(gs: GameState):
    """Weeks 1-3: study main skill. Weeks 4+: apply + interview + gig if needed."""
    _try_shop(gs)
    if gs.week <= 3:
        # Also study comm 1x
        if gs.free_energy() >= 1:
            gs.action_study(COMMUNICATION)
        while gs.free_energy() >= 1:
            gs.action_study(gs.direction)
    else:
        # Study 2-3 times
        study_count = random.choice([2, 3])
        for _ in range(study_count):
            if gs.free_energy() >= 1:
                gs.action_study(gs.direction)

        # Interview available
        for lid, app in list(gs.applications.items()):
            if app.status == HAS_INTERVIEW and gs.free_energy() >= 2:
                gs.action_interview(lid)

        # Apply to matching jobs
        applied_count = 0
        for listing in list(gs.listings):
            if gs.free_energy() < 1:
                break
            has_match = any(req.skill == gs.direction for req in listing.actual_skill_reqs)
            if has_match and listing.listing_id not in gs.applications:
                gs.action_focused_apply(listing)
                applied_count += 1
                if applied_count >= 2:
                    break

        # Accept best offer
        _accept_best_offer(gs)

        # Gig if cash < 2000
        if gs.cash < 2000 and gs.free_energy() >= GIG_ENERGY_PARTTIME:
            gs.action_gig_parttime()

        # Study with remaining
        while gs.free_energy() >= 1:
            gs.action_study(gs.direction)


def strategy_aggressive_apply(gs: GameState):
    """Weeks 1-2: study. Weeks 3-12: mass apply, interview, study remaining."""
    _try_shop(gs)
    if gs.week <= 2:
        while gs.free_energy() >= 1:
            gs.action_study(gs.direction)
    else:
        # Mass apply (1 EP)
        if gs.free_energy() >= 1:
            gs.action_mass_apply()

        # Interview all available
        for lid, app in list(gs.applications.items()):
            if app.status == HAS_INTERVIEW and gs.free_energy() >= 2:
                gs.action_interview(lid)

        # Accept best offer
        _accept_best_offer(gs)

        # Study with remaining energy
        while gs.free_energy() >= 1:
            gs.action_study(gs.direction)


def strategy_balanced(gs: GameState):
    """Each week: study 2-3, apply 1-2, interview if available, gig if cash < 2000."""
    _try_shop(gs)
    # Study main skill 2-3 times
    study_count = random.choice([2, 3])
    for _ in range(study_count):
        if gs.free_energy() >= 1:
            gs.action_study(gs.direction)

    # Also study communication sometimes
    if gs.week <= 4 and gs.free_energy() >= 1:
        gs.action_study(COMMUNICATION)

    # Interview available
    for lid, app in list(gs.applications.items()):
        if app.status == HAS_INTERVIEW and gs.free_energy() >= 2:
            gs.action_interview(lid)

    # Apply to 1-2 matching jobs
    applied = 0
    for listing in gs.listings:
        if gs.free_energy() < 1:
            break
        has_match = any(req.skill == gs.direction for req in listing.actual_skill_reqs)
        if has_match and listing.listing_id not in gs.applications:
            gs.action_focused_apply(listing)
            applied += 1
            if applied >= 2:
                break

    # Accept best offer
    _accept_best_offer(gs)

    # Gig if cash < 2000
    if gs.cash < 2000:
        if gs.free_energy() >= GIG_ENERGY_PARTTIME:
            gs.action_gig_parttime()

    # Use remaining energy on study
    while gs.free_energy() >= 1:
        gs.action_study(gs.direction)


def strategy_outsource_focus(gs: GameState):
    """Study main skill to lv 4 ASAP, then outsource. Apply opportunistically."""
    _try_shop(gs)
    if gs.skills[gs.direction] < 4:
        # Rush to level 4
        while gs.free_energy() >= 1:
            gs.action_study(gs.direction)
    else:
        # Take outsource if available
        if gs.current_outsource and gs.current_outsource["skill"] == gs.direction:
            gs.action_outsource()
        elif gs.current_outsource:
            # Take any outsource we qualify for
            gs.action_outsource()

        # Interview available
        for lid, app in list(gs.applications.items()):
            if app.status == HAS_INTERVIEW and gs.free_energy() >= 2:
                gs.action_interview(lid)

        # Apply to matching jobs opportunistically (1-2)
        applied = 0
        for listing in gs.listings:
            if gs.free_energy() < 1:
                break
            has_match = any(req.skill == gs.direction for req in listing.actual_skill_reqs)
            if has_match and listing.listing_id not in gs.applications:
                gs.action_focused_apply(listing)
                applied += 1
                if applied >= 1:
                    break

        _accept_best_offer(gs)

        # Study with remaining
        while gs.free_energy() >= 1:
            gs.action_study(gs.direction)


def strategy_bigco_rush(gs: GameState):
    """Study algorithm intensely (weeks 1-6), then only apply to big company jobs."""
    _try_shop(gs)
    if gs.week <= 4:
        # Pure algorithm study
        while gs.free_energy() >= 1:
            gs.action_study(ALGORITHM)
    elif gs.week <= 6:
        # Mix algorithm + communication
        for _ in range(4):
            if gs.free_energy() >= 1:
                gs.action_study(ALGORITHM)
        while gs.free_energy() >= 1:
            gs.action_study(COMMUNICATION)
    else:
        # Apply to big company jobs only
        applied = 0
        for listing in gs.listings:
            if gs.free_energy() < 1:
                break
            if listing.company.scale == BIG and listing.listing_id not in gs.applications:
                gs.action_focused_apply(listing)
                applied += 1
                if applied >= 3:
                    break

        # Interview
        for lid, app in list(gs.applications.items()):
            if app.status == HAS_INTERVIEW and gs.free_energy() >= 2:
                gs.action_interview(lid)

        _accept_best_offer(gs)

        # Study remaining
        while gs.free_energy() >= 1:
            if gs.skills[ALGORITHM] < gs.skills[gs.direction] + 2:
                gs.action_study(ALGORITHM)
            else:
                gs.action_study(gs.direction)


def _accept_best_offer(gs: GameState):
    """Accept the highest salary offer available."""
    best_lid = None
    best_salary = 0
    for lid, app in gs.applications.items():
        if app.status == OFFER and app.listing.actual_salary > best_salary:
            best_salary = app.listing.actual_salary
            best_lid = lid
    if best_lid:
        gs.action_accept_offer(best_lid)


# ============================================================
#  SIMULATION
# ============================================================

STRATEGIES = {
    "pure_gig": strategy_pure_gig,
    "study_first": strategy_study_first,
    "aggressive_apply": strategy_aggressive_apply,
    "balanced": strategy_balanced,
    "outsource_focus": strategy_outsource_focus,
    "bigco_rush": strategy_bigco_rush,
}

DIRECTIONS = [BACKEND, FRONTEND, ALGORITHM, DATA_ENGINEERING, INFRASTRUCTURE]

DIRECTION_NAMES = {
    BACKEND: "Backend",
    FRONTEND: "Frontend",
    ALGORITHM: "Algorithm",
    DATA_ENGINEERING: "DataEng",
    INFRASTRUCTURE: "Infra",
}

@dataclass
class SimResult:
    rank: str = "F"
    projected_income: int = 0
    bankrupt: bool = False
    employed: bool = False
    total_offers: int = 0
    first_offer_week: Optional[int] = None
    main_skill_level: int = 0


def run_single(strategy_fn, direction: str) -> SimResult:
    gs = GameState(direction)
    for week_num in range(1, MAX_WEEKS + 1):
        if gs.bankrupt:
            break
        gs.week = week_num  # Ensure week is set correctly before strategy
        # Reset energy at start of each week (already done in settle_week for subsequent weeks)
        if week_num > 1:
            pass  # energy already set by settle_week

        strategy_fn(gs)

        if gs.bankrupt:
            break

        gs.settle_week()

        if gs.bankrupt:
            break

    # Final: try to accept any pending offer if not employed
    if not gs.current_job and not gs.bankrupt:
        _accept_best_offer(gs)

    result = SimResult()
    result.rank = gs.get_rank()
    result.projected_income = gs.calc_projected_income()
    result.bankrupt = gs.bankrupt
    result.employed = gs.current_job is not None
    result.total_offers = gs.total_offers
    result.first_offer_week = gs.first_offer_week
    result.main_skill_level = gs.get_main_skill_level()
    return result


def run_simulations(strategy_name: str, strategy_fn, direction: str, n: int) -> dict:
    results = []
    for _ in range(n):
        r = run_single(strategy_fn, direction)
        results.append(r)

    ranks = {"S": 0, "A": 0, "B": 0, "C": 0, "F": 0}
    incomes = []
    offers_list = []
    first_offer_weeks = []
    bankruptcy_count = 0
    employment_count = 0
    skill_levels = []

    for r in results:
        ranks[r.rank] += 1
        incomes.append(r.projected_income)
        offers_list.append(r.total_offers)
        if r.first_offer_week is not None:
            first_offer_weeks.append(r.first_offer_week)
        if r.bankrupt:
            bankruptcy_count += 1
        if r.employed:
            employment_count += 1
        skill_levels.append(r.main_skill_level)

    total = len(results)
    return {
        "strategy": strategy_name,
        "direction": DIRECTION_NAMES[direction],
        "S%": ranks["S"] / total * 100,
        "A%": ranks["A"] / total * 100,
        "B%": ranks["B"] / total * 100,
        "C%": ranks["C"] / total * 100,
        "F%": ranks["F"] / total * 100,
        "avg_income": statistics.mean(incomes),
        "median_income": statistics.median(incomes),
        "avg_first_offer": statistics.mean(first_offer_weeks) if first_offer_weeks else float("nan"),
        "avg_offers": statistics.mean(offers_list),
        "bankruptcy%": bankruptcy_count / total * 100,
        "employment%": employment_count / total * 100,
        "avg_skill": statistics.mean(skill_levels),
    }


# ============================================================
#  OUTPUT
# ============================================================

def print_table(all_results: list):
    header = (
        f"{'Strategy':<20} {'Dir':<9} "
        f"{'S%':>5} {'A%':>5} {'B%':>5} {'C%':>5} {'F%':>5} "
        f"{'AvgInc':>8} {'MedInc':>8} "
        f"{'1stOff':>6} {'Offers':>6} "
        f"{'Bnkrpt':>6} {'Employ':>6} {'Skill':>5}"
    )
    sep = "-" * len(header)

    print("\n" + "=" * len(header))
    print("  OfferNotFound Monte Carlo Balance Simulation")
    print(f"  {NUM_SIMULATIONS} runs per strategy x direction ({len(all_results)} combinations)")
    print("=" * len(header))
    print()
    print(header)
    print(sep)

    current_strategy = None
    for r in all_results:
        if r["strategy"] != current_strategy:
            if current_strategy is not None:
                print(sep)
            current_strategy = r["strategy"]

        first_off_str = f"{r['avg_first_offer']:.1f}" if r["avg_first_offer"] == r["avg_first_offer"] else "  N/A"
        print(
            f"{r['strategy']:<20} {r['direction']:<9} "
            f"{r['S%']:5.1f} {r['A%']:5.1f} {r['B%']:5.1f} {r['C%']:5.1f} {r['F%']:5.1f} "
            f"{r['avg_income']:8.0f} {r['median_income']:8.0f} "
            f"{first_off_str:>6} {r['avg_offers']:6.2f} "
            f"{r['bankruptcy%']:5.1f}% {r['employment%']:5.1f}% {r['avg_skill']:5.1f}"
        )
    print(sep)


def print_analysis(all_results: list):
    print("\n")
    print("=" * 70)
    print("  BALANCE ANALYSIS")
    print("=" * 70)

    issues_found = False

    # Aggregate by strategy
    strat_data = {}
    for r in all_results:
        s = r["strategy"]
        if s not in strat_data:
            strat_data[s] = {"SA": [], "bankruptcy": [], "income": [], "offers": [], "F": []}
        strat_data[s]["SA"].append(r["S%"] + r["A%"])
        strat_data[s]["bankruptcy"].append(r["bankruptcy%"])
        strat_data[s]["income"].append(r["avg_income"])
        strat_data[s]["offers"].append(r["avg_offers"])
        strat_data[s]["F"].append(r["F%"])

    # 1. Dominant strategy check (S+A > all others by 20%+)
    print("\n[1] DOMINANT STRATEGY CHECK (S+A rate > all others by 20%+)")
    strat_avg_sa = {s: statistics.mean(d["SA"]) for s, d in strat_data.items()}
    sorted_sa = sorted(strat_avg_sa.items(), key=lambda x: -x[1])
    best_name, best_sa = sorted_sa[0]
    second_sa = sorted_sa[1][1] if len(sorted_sa) > 1 else 0
    if best_sa - second_sa > 20:
        print(f"  WARNING: '{best_name}' dominates with avg S+A={best_sa:.1f}%, "
              f"next best={second_sa:.1f}% (gap={best_sa - second_sa:.1f}%)")
        issues_found = True
    else:
        print(f"  OK - No single strategy dominates. Top: {best_name}={best_sa:.1f}%, "
              f"2nd: {sorted_sa[1][0]}={second_sa:.1f}%")
    for s, sa in sorted_sa:
        print(f"    {s:<20} avg S+A = {sa:.1f}%")

    # 2. Unviable strategy check
    print("\n[2] UNVIABLE STRATEGY CHECK (bankruptcy > 60% or S = 0%)")
    for s, d in strat_data.items():
        avg_bnk = statistics.mean(d["bankruptcy"])
        avg_s = statistics.mean([r["S%"] for r in all_results if r["strategy"] == s])
        if avg_bnk > 60:
            print(f"  WARNING: '{s}' avg bankruptcy={avg_bnk:.1f}% (too high)")
            issues_found = True
        if avg_s == 0:
            print(f"  WARNING: '{s}' has 0% S-rank across all directions")
            issues_found = True
    if not issues_found:
        print("  OK - All strategies have viable paths")

    # 3. Direction differentiation
    print("\n[3] DIRECTION DIFFERENTIATION CHECK (income variance < 5%)")
    dir_data = {}
    for r in all_results:
        d = r["direction"]
        if d not in dir_data:
            dir_data[d] = []
        dir_data[d].append(r["avg_income"])
    dir_avgs = {d: statistics.mean(vals) for d, vals in dir_data.items()}
    overall_avg = statistics.mean(list(dir_avgs.values()))
    low_var = []
    for d, avg in dir_avgs.items():
        pct_diff = abs(avg - overall_avg) / overall_avg * 100 if overall_avg > 0 else 0
        if pct_diff < 5:
            low_var.append((d, pct_diff))
    if len(low_var) >= len(dir_avgs) - 1:
        print("  WARNING: Most directions have < 5% income variance (no differentiation)")
        issues_found = True
    else:
        print("  OK - Directions show meaningful differentiation")
    for d in sorted(dir_avgs.keys()):
        pct = (dir_avgs[d] - overall_avg) / overall_avg * 100 if overall_avg > 0 else 0
        print(f"    {d:<9} avg income = ${dir_avgs[d]:,.0f} ({pct:+.1f}% vs mean)")

    # 4. Direction income gap
    print("\n[4] DIRECTION INCOME GAP CHECK (max gap > 30%)")
    max_inc = max(dir_avgs.values())
    min_inc = min(dir_avgs.values())
    gap_pct = (max_inc - min_inc) / max_inc * 100 if max_inc > 0 else 0
    best_dir = [d for d, v in dir_avgs.items() if v == max_inc][0]
    worst_dir = [d for d, v in dir_avgs.items() if v == min_inc][0]
    if gap_pct > 30:
        print(f"  WARNING: Income gap {gap_pct:.1f}% between {best_dir} (${max_inc:,.0f}) "
              f"and {worst_dir} (${min_inc:,.0f})")
        issues_found = True
    else:
        print(f"  OK - Income gap {gap_pct:.1f}% (best={best_dir} ${max_inc:,.0f}, "
              f"worst={worst_dir} ${min_inc:,.0f})")

    # 5. Offer rate check
    print("\n[5] OFFER RATE CHECK (avg > 5 or < 0.3)")
    for s, d in strat_data.items():
        avg_off = statistics.mean(d["offers"])
        if avg_off > 5:
            print(f"  WARNING: '{s}' avg offers = {avg_off:.2f} (too many, trivializes game)")
            issues_found = True
        elif avg_off < 0.3:
            print(f"  WARNING: '{s}' avg offers = {avg_off:.2f} (too few, frustrating)")
            issues_found = True
        else:
            print(f"  OK: '{s}' avg offers = {avg_off:.2f}")

    # 6. Summary by strategy
    print("\n[6] STRATEGY SUMMARY (avg across all directions)")
    print(f"  {'Strategy':<20} {'Avg Income':>10} {'S+A%':>6} {'Bnkrpt%':>8} {'Employ%':>8} {'Offers':>7}")
    print(f"  {'-'*20} {'-'*10} {'-'*6} {'-'*8} {'-'*8} {'-'*7}")
    for s in STRATEGIES:
        rows = [r for r in all_results if r["strategy"] == s]
        avg_inc = statistics.mean([r["avg_income"] for r in rows])
        avg_sa = statistics.mean([r["S%"] + r["A%"] for r in rows])
        avg_bnk = statistics.mean([r["bankruptcy%"] for r in rows])
        avg_emp = statistics.mean([r["employment%"] for r in rows])
        avg_off = statistics.mean([r["avg_offers"] for r in rows])
        print(f"  {s:<20} ${avg_inc:>9,.0f} {avg_sa:5.1f}% {avg_bnk:6.1f}% {avg_emp:7.1f}% {avg_off:6.2f}")

    print()
    if not issues_found:
        print("  >>> No critical balance issues detected.")
    else:
        print("  >>> Balance issues found. Review warnings above.")
    print()


# ============================================================
#  MAIN
# ============================================================

def main():
    print("Running Monte Carlo simulation...")
    print(f"  Strategies: {len(STRATEGIES)}")
    print(f"  Directions: {len(DIRECTIONS)}")
    print(f"  Simulations per combo: {NUM_SIMULATIONS}")
    print(f"  Total simulations: {len(STRATEGIES) * len(DIRECTIONS) * NUM_SIMULATIONS:,}")
    print()

    all_results = []
    total_combos = len(STRATEGIES) * len(DIRECTIONS)
    done = 0

    for strat_name, strat_fn in STRATEGIES.items():
        for direction in DIRECTIONS:
            done += 1
            sys.stdout.write(f"\r  Progress: {done}/{total_combos} "
                             f"({strat_name} x {DIRECTION_NAMES[direction]})          ")
            sys.stdout.flush()
            result = run_simulations(strat_name, strat_fn, direction, NUM_SIMULATIONS)
            all_results.append(result)

    sys.stdout.write("\r  Progress: complete!                                         \n")

    print_table(all_results)
    print_analysis(all_results)


if __name__ == "__main__":
    main()
