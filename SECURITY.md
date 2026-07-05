# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Instead, use
GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository — go to the **Security** tab and choose **Report a
vulnerability**. That channel is private and goes straight to the maintainers.

Please include what you found, how to reproduce it, and the impact. You'll get an
acknowledgement as soon as reasonably possible.

## Scope & threat model

Sonos Config talks to speakers over their **local, unauthenticated UPnP/SOAP**
interface on port 1400 — the same interface the speakers already expose to
everything on the LAN. The app:

- sends only control/configuration commands the speakers already accept from any
  local device;
- makes **no outbound cloud calls** and stores no credentials;
- uses plaintext HTTP because that is the only transport the speakers offer on
  the local control channel (this is a property of Sonos, not a choice of this
  app).

Security-relevant areas worth scrutiny:

- parsing of untrusted device responses (SOAP / `ZoneGroupTopology` /
  `device_description.xml` XML);
- the SSDP discovery path;
- any future feature that resolves or executes URIs returned by a device.

## Supported versions

This project is pre-1.0; fixes land on `main`. Please test against the latest
`main` before reporting.
