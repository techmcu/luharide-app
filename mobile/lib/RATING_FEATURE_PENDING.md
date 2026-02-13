# Rating Feature - PENDING

## Planned Flow

1. **After ride booked** – Passenger and driver can rate each other
2. **5 minutes after ride start** – Send email to user prompting to rate
3. **Store ratings** – Backend stores rating (1-5 stars) + optional comment
4. **Display** – Driver/Passenger profile shows real average rating

## Current State

- Fake "4.8" rating removed. Shows "No ratings yet" / "Complete rides to get rated"
- Rating tables/schema: Not yet created
- Email trigger: Pending

## To Implement Later

- [ ] Create `ratings` table (user_id, rater_id, trip_id, rating, comment, created_at)
- [ ] Add rating API: POST /api/ratings
- [ ] Add cron/job: 5 min after trip start → send rating email
- [ ] Update profile to fetch and show real average rating
