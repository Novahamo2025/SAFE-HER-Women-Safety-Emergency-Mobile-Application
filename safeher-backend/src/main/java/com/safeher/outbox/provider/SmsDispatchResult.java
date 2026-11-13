package com.safeher.outbox.provider;

/**
 * Result record capturing the provider's dispatch outcome.
 *
 * Outcomes:
 * - ACCEPTED: Provider accepted the message (returns a provider reference ID).
 * - REJECTED: Provider explicitly rejected the dispatch (e.g. invalid phone number, blacklisted, template mismatch).
 * - UNCERTAIN: Transient network error, timeout, HTTP 5xx, or unparseable response.
 *              An UNCERTAIN result must NEVER trigger blind re-dispatch.
 */
public record SmsDispatchResult(
        Outcome outcome,
        String providerRef,
        String errorMessage
) {
    public enum Outcome {
        ACCEPTED,
        REJECTED,
        UNCERTAIN
    }

    public static SmsDispatchResult accepted(String providerRef) {
        return new SmsDispatchResult(Outcome.ACCEPTED, providerRef, null);
    }

    public static SmsDispatchResult rejected(String errorMessage) {
        return new SmsDispatchResult(Outcome.REJECTED, null, errorMessage);
    }

    public static SmsDispatchResult uncertain(String errorMessage) {
        return new SmsDispatchResult(Outcome.UNCERTAIN, null, errorMessage);
    }

    public boolean isAccepted() {
        return outcome == Outcome.ACCEPTED;
    }

    public boolean isRejected() {
        return outcome == Outcome.REJECTED;
    }

    public boolean isUncertain() {
        return outcome == Outcome.UNCERTAIN;
    }
}
