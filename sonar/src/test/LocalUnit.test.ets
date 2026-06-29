import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { SubsonicClient } from '../main/ets/sonar/api/SubsonicClient';
import { SubsonicUrlUtil } from '../main/ets/sonar/network/api/SubsonicUrlUtil';
import { SubsonicApiError } from '../main/ets/sonar/api/SubsonicTypes';
import { AuthStore, SavedAuth } from '../main/ets/sonar/auth/AuthStore';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('normalizeServerUrl_withPath', 0, () => {
      const url = SubsonicUrlUtil.normalizeServerUrl('https://demo.navidrome.local/music/');
      expect(url).assertEqual('https://demo.navidrome.local/music');
    });

    it('normalizeServerUrl_invalid', 0, () => {
      let gotError = false;
      try {
        SubsonicUrlUtil.normalizeServerUrl('demo.navidrome.local');
      } catch (err) {
        gotError = err instanceof SubsonicApiError;
      }
      expect(gotError).assertTrue();
    });

    it('toArray_shouldNormalize', 0, () => {
      const one = SubsonicClient.toArray<string>('a');
      const many = SubsonicClient.toArray<string>(['x', 'y']);
      const empty = SubsonicClient.toArray<number>(undefined);

      expect(one.length).assertEqual(1);
      expect(one[0]).assertEqual('a');
      expect(many.length).assertEqual(2);
      expect(many[0]).assertEqual('x');
      expect(empty.length).assertEqual(0);
    });

    it('resolveEndpointUrl_localAndRemote', 0, () => {
      const auth: SavedAuth = {
        remoteServerUrl: 'https://remote.example.com',
        localServerUrl: 'http://192.168.1.10:4533',
        activeEndpoint: 'remote',
        username: 'u',
        salt: 's',
        token: 't',
        authMode: 'subsonicToken'
      };
      const localUrl = AuthStore.resolveEndpointUrl(auth, 'local');
      const remoteUrl = AuthStore.resolveEndpointUrl(auth, 'remote');
      expect(localUrl).assertEqual('http://192.168.1.10:4533');
      expect(remoteUrl).assertEqual('https://remote.example.com');
    });
  });
}