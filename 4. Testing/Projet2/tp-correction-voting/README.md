Ce dépôt contient 34 tests pour le contrat Voting.sol, réalisés avec Foundry.

Ce qui a été testé :

    Ajout des électeurs (addVoter)

        Vérification des droits (seul l’owner peut ajouter).

        Vérifie qu’un électeur ne peut être ajouté deux fois.

        Fuzzing pour tester avec plusieurs adresses.

    Ajout des propositions (addProposal)

        Ne peut être fait que durant la bonne phase.

        Les propositions vides sont rejetées.

        Vérifie l’enregistrement correct de la description.

    Déroulement du vote

        Test de toutes les transitions de workflow avec vérification des événements (WorkflowStatusChange).

        Test du vote simple, du double vote interdit, et du vote sur un ID inexistant.

    Décompte final (tallyVotes)

        Vérifie que le gagnant est bien désigné.

        Test d’un cas d’égalité entre propositions : le contrat retourne bien un gagnant parmi les ex æquo.

    Événements

        Chaque action importante déclenche un événement (ajout d’électeur, de proposition, vote, changement de phase), et leur émission est vérifiée.
