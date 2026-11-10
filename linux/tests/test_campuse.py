"""Regression tests without a Wi-Fi adapter or changes to the host network."""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location('campuse', Path(__file__).resolve().parents[1] / 'campuse.py')
campuse = importlib.util.module_from_spec(spec)
spec.loader.exec_module(campuse)


def result(code=0, stderr=''):
    return subprocess.CompletedProcess(['nmcli'], code, stdout='', stderr=stderr)


class ActivationTests(unittest.TestCase):
    def setUp(self):
        self.session = campuse.Session('wlan0', 'original')
        self.session.temporary = 'temporary'

    def test_activation_waits_longer_than_dhcp_and_python_waits_for_nmcli(self):
        with patch.object(campuse.subprocess, 'run', return_value=result()) as run:
            campuse.activate('temporary', 'wlan0', ask=True)
        args = run.call_args.args[0]
        wait = int(args[args.index('--wait') + 1])
        self.assertEqual(args.count('--wait'), 1)
        self.assertGreater(wait, campuse.DHCP_TIMEOUT)
        self.assertGreater(run.call_args.kwargs['timeout'], wait)
        self.assertIn('--ask', args)

    def test_python_timeout_has_an_actionable_error(self):
        with patch.object(campuse.subprocess, 'run', side_effect=subprocess.TimeoutExpired('nmcli', 105)):
            with self.assertRaisesRegex(RuntimeError, 'Activation Wi-Fi sans reponse'):
                campuse.activate('temporary', 'wlan0', ask=True)

    def test_dhcp_success(self):
        with patch.object(campuse, 'nm', return_value=result()) as nm, \
                patch.object(campuse, 'activate', return_value=result()), \
                patch.object(campuse, 'preserve', return_value=True):
            self.assertTrue(self.session.try_dhcp())
        args = nm.call_args.args
        self.assertEqual(args[args.index('ipv4.dhcp-timeout') + 1], str(campuse.DHCP_TIMEOUT))

    def test_authentication_timeout_never_allows_static_fallback(self):
        with patch.object(campuse, 'nm', return_value=result()), \
                patch.object(campuse, 'activate', return_value=result(3)), \
                patch.object(campuse, 'preserve', return_value=False), \
                patch.object(campuse, 'field', side_effect=['50 (config)', '0 (none)']):
            with self.assertRaisesRegex(RuntimeError, 'Delai.*Etat NetworkManager : 50.*Aucune IP statique'):
                self.session.try_dhcp()

    def test_authentication_failure_never_allows_static_fallback(self):
        for reason in ('7 (no-secrets)', '9 (supplicant-disconnect)', '11 (supplicant-config-failed)'):
            with self.subTest(reason=reason), \
                    patch.object(campuse, 'nm', return_value=result()), \
                    patch.object(campuse, 'activate', return_value=result(4)), \
                    patch.object(campuse, 'preserve', return_value=False), \
                    patch.object(campuse, 'field', side_effect=['120 (failed)', reason]):
                with self.assertRaisesRegex(RuntimeError, 'Activation Wi-Fi non aboutie.*Aucune IP statique'):
                    self.session.try_dhcp()

    def test_unknown_state_is_not_treated_as_dhcp_failure_even_after_success_exit(self):
        with patch.object(campuse, 'nm', return_value=result()), \
                patch.object(campuse, 'activate', return_value=result()), \
                patch.object(campuse, 'preserve', return_value=False), \
                patch.object(campuse, 'field', return_value=''):
            with self.assertRaisesRegex(RuntimeError, 'Aucune IP statique'):
                self.session.try_dhcp()

    def test_ip_configuration_failure_allows_static_fallback(self):
        for state, reason in [('70 (ip-config)', '0 (none)'), ('120 (failed)', '5 (ip-config-unavailable)'),
                              ('120 (failed)', '6 (ip-config-expired)')]:
            with self.subTest(state=state, reason=reason), \
                    patch.object(campuse, 'nm', return_value=result()), \
                    patch.object(campuse, 'activate', return_value=result(3)), \
                    patch.object(campuse, 'preserve', return_value=False), \
                    patch.object(campuse, 'field', side_effect=[state, reason]):
                self.assertFalse(self.session.try_dhcp())

    def test_static_activation_uses_the_same_extended_wait(self):
        zone = {'cidr': 16, 'gateway': '10.1.0.1'}
        with patch.object(campuse, 'nm', return_value=result()), \
                patch.object(campuse, 'activate', return_value=result()) as activate:
            self.session.apply('10.1.2.3', zone)
        activate.assert_called_once_with('temporary', 'wlan0', ask=True)


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.session = campuse.Session('wlan0', 'original')
        self.session.temporary = 'temporary'
        self.session.changed = True

    def test_restore_timeout_still_deletes_temporary_profile(self):
        with patch.object(campuse, 'active', return_value='temporary'), \
                patch.object(campuse, 'nm', return_value=result()) as nm, \
                patch.object(campuse, 'activate', return_value=result(3)):
            with self.assertRaisesRegex(RuntimeError, "profil d'origine impossible.*90 secondes"):
                self.session.close()
        nm.assert_any_call('connection', 'delete', 'uuid', 'temporary')

    def test_both_restore_and_delete_errors_are_reported(self):
        def nm(*args, **kwargs):
            if args[:2] == ('connection', 'delete'):
                raise RuntimeError('delete failed')
            return result()
        with patch.object(campuse, 'active', return_value='temporary'), \
                patch.object(campuse, 'nm', side_effect=nm), \
                patch.object(campuse, 'activate', return_value=result(3)):
            with self.assertRaisesRegex(RuntimeError, 'Reconnexion.*Suppression.*delete failed'):
                self.session.close()

    def test_restore_uses_extended_wait_without_prompting_for_credentials(self):
        with patch.object(campuse, 'active', return_value='temporary'), \
                patch.object(campuse.subprocess, 'run', return_value=result()) as run:
            self.session.close()
        activation = next(call for call in run.call_args_list if 'up' in call.args[0])
        args = activation.args[0]
        self.assertEqual(args[args.index('--wait') + 1], str(campuse.ACTIVATION_WAIT))
        self.assertNotIn('--ask', args)
        self.assertGreater(activation.kwargs['timeout'], campuse.ACTIVATION_WAIT)

    def test_user_selected_network_is_left_alone(self):
        with patch.object(campuse, 'active', return_value='other-network'), \
                patch.object(campuse, 'activate') as activate, \
                patch.object(campuse, 'nm', return_value=result()) as nm:
            self.session.close()
        activate.assert_not_called()
        nm.assert_called_once_with('connection', 'delete', 'uuid', 'temporary')

    def test_initial_error_survives_cleanup_timeout(self):
        session = Mock()
        session.close.side_effect = RuntimeError('restore timed out')
        primary = RuntimeError('authentication failed')
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            with self.assertRaises(RuntimeError) as caught:
                try:
                    raise primary
                finally:
                    campuse.finish_session(session)
        self.assertIs(caught.exception, primary)
        self.assertIn('nettoyage incomplet : restore timed out', stderr.getvalue())

    def test_cleanup_error_after_success_is_not_silenced(self):
        session = Mock()
        session.close.side_effect = RuntimeError('restore timed out')
        with self.assertRaisesRegex(RuntimeError, 'restore timed out'):
            campuse.finish_session(session)

    def test_interrupt_survives_cleanup_error_and_signal_handlers_are_restored(self):
        session = Mock()
        session.close.side_effect = RuntimeError('restore timed out')
        signals = (campuse.signal.SIGINT, campuse.signal.SIGTERM, campuse.signal.SIGHUP)
        before = [campuse.signal.getsignal(sig) for sig in signals]
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(KeyboardInterrupt):
                try:
                    raise KeyboardInterrupt
                finally:
                    campuse.finish_session(session)
        self.assertEqual(before, [campuse.signal.getsignal(sig) for sig in signals])


class MainTests(unittest.TestCase):
    def run_main(self, session, answer):
        with patch.object(campuse.shutil, 'which', return_value='/usr/bin/tool'), \
                patch.object(campuse, 'field', return_value='running'), \
                patch.object(campuse, 'wifi_device', return_value='wlan0'), \
                patch.object(campuse, 'preserve', return_value=False), \
                patch.object(campuse, 'profiles', return_value=[('original', 'saved account')]), \
                patch.object(campuse, 'choose', return_value='original'), \
                patch.object(campuse, 'active', return_value='original'), \
                patch.object(campuse, 'Session', return_value=session), \
                patch('builtins.input', side_effect=answer):
            campuse.main()

    def test_dhcp_connection_stays_open_until_user_exits(self):
        session = Mock()
        session.try_dhcp.return_value = True
        prompts = []
        def answer(prompt):
            prompts.append(prompt)
            session.close.assert_not_called()
            return ''
        with patch.object(campuse, 'repair') as repair:
            self.run_main(session, answer)
        self.assertEqual(len(prompts), 1)
        self.assertIn('Gardez ce terminal ouvert', prompts[0])
        session.close.assert_called_once_with()
        repair.assert_not_called()

    def test_dhcp_failure_enters_repair_and_then_cleans_up(self):
        session = Mock()
        session.try_dhcp.return_value = False
        with patch.object(campuse, 'repair') as repair:
            self.run_main(session, Mock(side_effect=AssertionError('unexpected prompt')))
        repair.assert_called_once_with('wlan0', 'original', dhcp_failed=True, session=session)
        session.close.assert_called_once_with()

    def test_activation_failure_is_preserved_and_never_enters_repair(self):
        session = Mock()
        session.try_dhcp.side_effect = RuntimeError('authentication failed')
        session.close.side_effect = RuntimeError('restore timed out')
        with contextlib.redirect_stderr(io.StringIO()), \
                patch.object(campuse, 'repair') as repair:
            with self.assertRaisesRegex(RuntimeError, 'authentication failed'):
                self.run_main(session, Mock(side_effect=AssertionError('unexpected prompt')))
        session.close.assert_called_once_with()
        repair.assert_not_called()


if __name__ == '__main__':
    unittest.main()
