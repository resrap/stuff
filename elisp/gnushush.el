;;; gnushush.el --- make Gnus be a little secretive in message headers
     
;; Copyright (C) 2001,2002 Neil W. Van Dyke

;; Author:   Neil W. Van Dyke <neil@neilvandyke.org>
;; Version:  1.2
;; X-URL:    http://www.neilvandyke.org/gnushush/
;; X-CVS:    $Id: gnushush.el,v 1.21 2002/12/02 19:56:07 neil Exp $ GMT

;; This is free software; you can redistribute it and/or modify it under the
;; terms of the GNU General Public License as published by the Free Software
;; Foundation; either version 2, or (at your option) any later version.  This
;; is distributed in the hope that it will be useful, but without any warranty;
;; without even the implied warranty of merchantability or fitness for a
;; particular purpose.  See the GNU General Public License for more details.
;; You should have received a copy of the GNU General Public License along with
;; GNU Emacs; see the file `COPYING'.  If not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

;;; Commentary:

;; The Gnus newsreader (at least version 5.8.3) can be a little bit of a
;; blabbermouth sometimes, needlessly revealing information in your mail
;; headers that reduces your privacy or puts you at slightly greater risk of
;; network attacks against your computer's security.
;;
;; `gnushush.el' is a small package that pressures Gnus into being a little
;; bit quieter.  To use it, put the following line in your `.emacs' file:
;;
;;     (require 'gnushush)
;;
;; There are some options below that you can set.  Just be sure you know what
;; you're doing, since wrongly setting some of these options can cause problems
;; for other people.  The defaults settings are pretty benign.
;;
;; Some later version of Gnus will probably obviate the need for this package,
;; but isn't it nice that Emacs Lisp lets us so easily modify software using
;; layered packages, rather than having to wait for some huge canonical package
;; to be modified?

;;; Change Log:

;; [Version 1.2, 02-Dec-2002] Fixed `gnuhush' typos (thanks Frederik Fouvry).
;;
;; [Version 1.1, 15-Oct-2002] Updated email address.
;;
;; [Version 1.0, 15-Feb-2001] Initial release.

;;; Code:

(defconst gnushush-version "1.2")

(require 'custom)
(require 'message)

(defgroup gnushush nil
  "Make Gnus give away a little less info in message headers."
  :group  'gnus
  :prefix "gnushush-"
  :link   '(url-link "http://www.neilvandyke.org/gnushush/"))

(defcustom gnushush-enable-p t
  "Enable `gnushush' functionality?"
  :group 'gnushush
  :type  'boolean)

(defcustom gnushush-fqdn 'real
  "Fully-qualified domain name for Message-IDs (use with caution).  This can be
set to `real', in which case Gnus behaves as normal, or to a string with the
FQDN of your choosing.  It is important that you only specify an FQDN if you
know what you are doing and you control the domain of the FQDN (e.g., you have
a second-level domain registered to you for your personal home network, and you
are certain that disguising `laptop.bedroom.homedomain.foo' as `homedomain.foo'
will not make it possible to have duplicate Message-IDs generated by any
machines under the `homedomain.foo' domain)."
  :group 'gnushush
  :type  '(choice (const real) string))

(defcustom gnushush-uid 'random
  "UID handling for Message-IDs.
Normally, Gnus will encode your numeric user ID (UID) into each Message-ID,
which can reveal that you are using the same computer account to post to Usenet
under multiple identities.  There is also a *small* risk that knowledge of a
UID can help an attacker break into your computer over the Internet.  In any
case, you may see little sense in publishing your UID to the world.  If this
variable If set to `real', then Gnus behaves as normal.  If set to `random',
a random number is used as a fake UID when the Message-ID is generated.  If
set to a positive integer, then that number will be used as the fake UID."
  :group 'gnushush
  :type  '(choice (const real) (const random) integer))

(defcustom gnushush-sender-header 'none
  "Handling of Sender headers.
You may wish to ``spam-proof'' your email address in the From headers of your
Usenet posts to avoid various email address harvesters that scour Usenet for
spam targets.  Or you may wish to hide your identity, by faking your email
address in the From header (*and via other means*, since simply modifying the
\From header is probably not adequate to conceal your identity).  The problem
is that Gnus is a bit of a tattletale -- when it sees a modified From header,
it will go and secretly add a Sender header that includes your username and
your computer's fully-qualified domain name.  If this variable is set to
`none', then `gnushush' will remove any Sender header added by Gnus before the
message is sent.  If this variable is set to `real', then any Sender header
will be left alone."
  :group 'gnushush
  :type  '(choice (const real) (const none)))

(defcustom gnushush-user-agent-header "Emacs Gnus"
  "Handling of User-Agent headers.
Gnus likes to add a User-Agent header to all messages that discloses what
versions of Gnus and Emacs you are running.  In general, security-wise, it is
best not to disclose what software and versions you are running, since that
advertises your vulnerability to particular security exploits.  If this
variable is set to `real', then the User-Agent header added by Gnus is left
unchanged.  If this variable is set to `none', then all User-Agent headers are
stripped before sending.  If this variable is set to a string, then the
contents of the string are used as the value of the User-Agent header.  By
default, `gnushush' will set the variable to acknowledge that you run the neato
Gnus and Emacs software, but does not say what versions.  The distinction is
minor, but there is no sense in needlessly advertising what software versions
you run."
  :group 'gnushush
  :type  '(choice (const real) (const none) string))

(defun gnushush-customize ()
  (interactive)
  (customize-group 'gnushush))

(defun gnushush-dummy-system-name ()
  gnushush-fqdn)

(defun gnushush-dummy-user-login-name (&optional uid)
  (progn "user"))

(defun gnushush-dummy-user-uid ()
  (cond ((eq gnushush-uid 'real)   (error "gnushush internal error"))
        ((eq gnushush-uid 'random) (random 1296))
        ((integerp gnushush-uid)   gnushush-uid)
        (t (error "gnushush-uid must be integer, 'random, or 'real"))))

(defadvice message-generate-headers (after gnushush-ad-mgh activate)
  (when gnushush-enable-p
    (let ((victims
           (delq nil
                 (list
                  (unless (eq gnushush-user-agent-header 'real) "User-Agent")
                  (unless (eq gnushush-sender-header     'real) "Sender")))))
      (when victims
        (save-match-data
          (save-restriction
            (message-narrow-to-headers)
            (goto-char (point-min))
            (let ((regexp (concat "^\\(" 
                                  (mapconcat 'identity victims "\\|")
                                  "\\):"))
                  (case-fold-search t))
              (while (re-search-forward regexp nil t)
                (delete-region (progn (beginning-of-line) (point))
                               (progn (forward-line)      (point)))))
            (when (stringp gnushush-user-agent-header)
              (goto-char (point-max))
              (unless (bolp) (insert "\n"))
              (insert "User-Agent: " gnushush-user-agent-header)
              (insert "\n"))))))))

(defadvice message-make-message-id (around gnushush-ad-mmmi activate protect)
  (let ((gnushush-saved-sn  (symbol-function 'system-name))
        (gnushush-saved-uln (symbol-function 'user-login-name))
        (gnushush-saved-uu  (symbol-function 'user-uid)))
    (unwind-protect
        (progn 
          (when gnushush-enable-p
            (unless (eq gnushush-fqdn 'real)
              (fset 'system-name     'gnushush-dummy-system-name))
            (unless (eq gnushush-uid 'real)
              (fset 'user-login-name 'gnushush-dummy-user-login-name)
              (fset 'user-uid        'gnushush-dummy-user-uid)))
          ad-do-it)
      (fset 'system-name     gnushush-saved-sn)
      (fset 'user-login-name gnushush-saved-uln)
      (fset 'user-uid        gnushush-saved-uu))))

(random t)

(provide 'gnushush)

;; gnushush.el ends here
