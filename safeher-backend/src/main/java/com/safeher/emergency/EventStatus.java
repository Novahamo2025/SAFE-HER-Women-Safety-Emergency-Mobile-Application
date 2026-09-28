package com.safeher.emergency;

public enum EventStatus {
    CREATED,
    ACTIVE,
    CANCELLED,
    COMPLETED,
    RESOLVED;

    /**
     * Validates whether a status transition is allowed.
     */
    public boolean canTransitionTo(EventStatus target) {
        return switch (this) {
            case CREATED -> target == ACTIVE || target == CANCELLED;
            case ACTIVE -> target == CANCELLED || target == COMPLETED || target == RESOLVED;
            case CANCELLED, COMPLETED, RESOLVED -> false; // Terminal states
        };
    }

    public static EventStatus fromString(String value) {
        try {
            return EventStatus.valueOf(value.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid event status: " + value);
        }
    }
}
